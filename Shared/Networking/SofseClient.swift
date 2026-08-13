import Foundation
import CoreLocation

// Cliente de la API SOFSE. Arribos (sin token), alertas (con token).
actor SofseClient {
    static let shared = SofseClient()

    private let base = URL(string: "https://api-servicios.sofse.gob.ar/v1")!
    private let session: URLSession
    private let tokenProvider: TokenProvider
    private let decoder = JSONDecoder()

    init(tokenProvider: TokenProvider = .shared, session: URLSession? = nil) {
        self.tokenProvider = tokenProvider
        if let session {
            self.session = session
        } else {
            let cfg = URLSessionConfiguration.default
            cfg.timeoutIntervalForRequest = 60
            cfg.timeoutIntervalForResource = 60
            self.session = URLSession(configuration: cfg)
        }
    }

    // MARK: - Arribos en vivo

    func arrivals(stationId: Int, limit: Int = 12, toStationId: Int? = nil, ramalId: Int? = nil) async throws -> [Arrival] {
        var items = [URLQueryItem(name: "cantidad", value: String(limit))]
        if let toStationId { items.append(URLQueryItem(name: "hasta", value: String(toStationId))) }
        if let ramalId { items.append(URLQueryItem(name: "ramal", value: String(ramalId))) }
        let data = try await get(path: "arribos/estacion/\(stationId)", query: items, auth: false)
        let wrapper = try decode(ArribosResponse.self, data)
        let serverNow = wrapper.timestamp.map { Date(timeIntervalSince1970: TimeInterval($0)) } ?? Date()

        var out: [Arrival] = []
        for r in wrapper.results ?? [] {
            // Filtrar los que ya pasaron (tienen llegada.real).
            if SofseDate.iso(r.arribo?.llegada?.real) != nil { continue }
            if let a = map(result: r, serverNow: serverNow, live: true) { out.append(a) }
        }
        return out.sorted { $0.secondsUntil < $1.secondsUntil }
    }

    // MARK: - Arribos por horario (fallback)

    func scheduledArrivals(stationId: Int, date: Date, time: String, toStationId: Int? = nil, limit: Int = 12) async throws -> [Arrival] {
        var items = [
            URLQueryItem(name: "cantidad", value: String(limit)),
            URLQueryItem(name: "fecha", value: Self.isoDate(date)),
            URLQueryItem(name: "hora", value: time)
        ]
        if let toStationId { items.append(URLQueryItem(name: "hasta", value: String(toStationId))) }
        let data = try await get(path: "arribos/estacion/\(stationId)", query: items, auth: false)
        let wrapper = try decode(ArribosResponse.self, data)
        let serverNow = wrapper.timestamp.map { Date(timeIntervalSince1970: TimeInterval($0)) } ?? date

        var out: [Arrival] = []
        for r in wrapper.results ?? [] {
            if let a = map(result: r, serverNow: serverNow, live: false) { out.append(a) }
        }
        return out.sorted { $0.secondsUntil < $1.secondsUntil }
    }

    // MARK: - Alertas

    func alerts() async throws -> [ServiceAlert] {
        do {
            async let gerencias = get(path: "infraestructura/gerencias", query: [], auth: true)
            async let ramales = get(path: "infraestructura/ramales", query: [], auth: true)
            let (gData, rData) = try await (gerencias, ramales)

            var raw: [AlertaDTO] = []
            if let g = try? decoder.decode([GerenciaAlertDTO].self, from: gData) {
                raw += g.flatMap { $0.alerta ?? [] }
            }
            if let r = try? decoder.decode([RamalAlertDTO].self, from: rData) {
                raw += r.compactMap { $0.alerta }
            }

            var seen = Set<String>()
            var out: [ServiceAlert] = []
            for dto in raw {
                guard let content = dto.contenido, !content.isEmpty else { continue }
                // Normalizar: colapsar espacios (incluye \u{00a0}) para deduplicar el mismo
                // texto repetido por línea (la API lo manda con espacios distintos).
                let key = content
                    .replacingOccurrences(of: "\u{00a0}", with: " ")
                    .components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                    .lowercased()
                if seen.contains(key) { continue }
                seen.insert(key)
                out.append(ServiceAlert(dto: dto))
            }
            return out.sorted { $0.criticality < $1.criticality }
        } catch {
            // Degradar a vacío si la auth o la red fallan. No tirar el error a la UI.
            return []
        }
    }

    // MARK: - Mapeo a dominio

    private func map(result r: ResultDTO, serverNow: Date, live: Bool) -> Arrival? {
        guard let s = r.servicio, let a = r.arribo else { return nil }
        let lineId = s.gerencia?.id ?? -1
        let line = TrainLine.line(id: lineId)
        let sentido = s.sentido ?? 1
        let ini = s.ramal?.cabeceraInicial
        let fin = s.ramal?.cabeceraFinal
        // sentido 1 = hacia cabecera final; 2 = hacia cabecera inicial.
        let destCab = sentido == 2 ? ini : fin
        let origCab = sentido == 2 ? fin : ini

        let scheduled = SofseDate.iso(a.llegada?.programada)
        let estimated = SofseDate.iso(a.llegada?.estimada)
        let tolerance = s.ramal?.tolerancia ?? DelayLogic.defaultTolerance
        let isCancelled = s.cancelacion != nil
        let seconds = a.segundos ?? 0

        let delay = DelayLogic.status(
            scheduled: scheduled,
            estimated: estimated,
            secondsUntil: seconds,
            serverNow: serverNow,
            tolerance: tolerance,
            isCancelled: isCancelled
        )

        var trainLoc: CLLocationCoordinate2D?
        if let lat = s.location?.lat, let lon = s.location?.long {
            trainLoc = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }

        let route: [RouteStop] = (s.estaciones ?? []).enumerated().map { idx, e in
            RouteStop(
                stationId: e.idElemento ?? -1,
                name: e.nombre ?? "",
                order: e.orden ?? idx,
                scheduled: SofseDate.iso(e.llegada?.programada),
                estimated: SofseDate.iso(e.llegada?.estimada),
                trackName: e.anden?.nombre,
                hasPassed: SofseDate.iso(e.llegada?.real) != nil
            )
        }

        let destName = destCab?.display ?? ""
        let sid = s.id
        let id = sid ?? "\(lineId)-\(destName)-\(scheduled?.timeIntervalSince1970 ?? Double(seconds))"

        return Arrival(
            id: id,
            serviceId: sid,
            lineId: lineId,
            line: line,
            ramalName: s.ramal?.nombre ?? line.nombre,
            destinationName: destName,
            originName: origCab?.display ?? "",
            trackName: a.anden?.nombre,
            scheduled: scheduled,
            estimated: estimated,
            secondsUntil: seconds,
            delay: delay,
            trainLocation: trainLoc,
            equipmentName: a.equipo?.nombre,
            isElectric: (a.equipo?.esElectrico ?? 0) == 1,
            isCancelled: isCancelled,
            direction: sentido,
            stateName: s.desde?.estado?.nombre,
            route: route
        )
    }

    // MARK: - Red

    private func get(path: String, query: [URLQueryItem], auth: Bool, retried: Bool = false) async throws -> Data {
        var comps = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        comps?.queryItems = query.isEmpty ? nil : query
        guard let url = comps?.url else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if auth {
            req.setValue(try await tokenProvider.token(), forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw APIError.transport(error)
        }
        guard let http = resp as? HTTPURLResponse else {
            throw APIError.transport(URLError(.badServerResponse))
        }

        // Reintento único ante 401/403: regenerar token y repetir.
        if auth, !retried, http.statusCode == 401 || http.statusCode == 403 {
            _ = try await tokenProvider.token(force: true)
            return try await get(path: path, query: query, auth: auth, retried: true)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(status: http.statusCode, body: String(data: data, encoding: .utf8))
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.decoding(error) }
    }

    private static func isoDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
