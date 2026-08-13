import Foundation
import CoreLocation

// Cliente de la API Transporte BA (subte + EcoBici). Auth por query string.
// Si faltan las credenciales (Secrets.plist ausente) tira APIError.noToken.
actor BAClient {
    static let shared = BAClient()

    private let base = URL(string: "https://apitransporte.buenosaires.gob.ar")!
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let cfg = URLSessionConfiguration.default
            cfg.timeoutIntervalForRequest = 30
            cfg.timeoutIntervalForResource = 30
            self.session = URLSession(configuration: cfg)
        }
    }

    // MARK: - Subte: arribos en vivo

    // Todos los trenes activos con sus paradas restantes.
    func subteTrips() async throws -> [SubteTrip] {
        let data = try await get(path: "subtes/forecastGTFS", flags: ["json": "1"])
        let resp = try decode(ForecastResponse.self, data)

        var trips: [SubteTrip] = []
        for entity in resp.Entity ?? [] {
            guard let linea = entity.Linea, let routeId = linea.Route_Id else { continue }
            let line = SubteLine.line(routeId: routeId)
            let direction = linea.Direction_ID ?? 0

            var stops: [SubteStop] = []
            for e in linea.Estaciones ?? [] {
                guard let sid = e.stop_id, let epoch = e.arrival?.time else { continue }
                let eta = Date(timeIntervalSince1970: TimeInterval(epoch))
                stops.append(SubteStop(
                    stopId: sid,
                    name: e.stop_name ?? "",
                    eta: eta,
                    delaySeconds: e.arrival?.delay ?? 0
                ))
            }
            guard !stops.isEmpty else { continue }
            trips.append(SubteTrip(line: line, direction: direction, stops: stops))
        }
        return trips
    }

    // Lista ordenada de estaciones de una línea, derivada de sus trips.
    // Sin trips activos -> [].
    func subteStations(line: SubteLine) async throws -> [String] {
        let trips = try await subteTrips().filter { $0.line.routeId == line.routeId }
        guard !trips.isEmpty else { return [] }

        var seen = Set<String>()
        var out: [String] = []
        // El trip más largo define el orden base; los demás completan huecos.
        for trip in trips.sorted(by: { $0.stops.count > $1.stops.count }) {
            for stop in trip.stops {
                let name = stop.name
                guard !name.isEmpty else { continue }
                let key = StationCatalog.normalize(name)
                if seen.contains(key) { continue }
                seen.insert(key)
                out.append(name)
            }
        }
        return out
    }

    // Arribos para el tablero de una estación, por dirección, ordenados por tiempo.
    // Destino = última estación del trip. Filtra los que ya pasaron.
    func subteArrivals(stationName: String) async throws -> [SubteArrival] {
        let trips = try await subteTrips()
        let target = StationCatalog.normalize(stationName)
        let now = Date()

        var out: [SubteArrival] = []
        for trip in trips {
            guard let stop = trip.stops.first(where: { StationCatalog.normalize($0.name) == target }) else { continue }
            let secondsUntil = Int(stop.eta.timeIntervalSince(now).rounded())
            if secondsUntil < 0 { continue }
            let destination = trip.stops.last?.name ?? ""
            out.append(SubteArrival(
                line: trip.line,
                direction: trip.direction,
                destinationName: destination,
                eta: stop.eta,
                secondsUntil: secondsUntil,
                delay: stop.delay
            ))
        }
        return out.sorted { $0.secondsUntil < $1.secondsUntil }
    }

    // MARK: - Subte: estado de servicio

    func subteAlerts() async throws -> [SubteAlertItem] {
        let data = try await get(path: "subtes/serviceAlerts", flags: ["json": "1"])
        let resp = try decode(AlertsResponse.self, data)

        var out: [SubteAlertItem] = []
        for entity in resp.entity ?? [] {
            guard let alert = entity.alert else { continue }
            let text = alert.header_text?.translation?.first?.text ?? ""
            guard !text.isEmpty else { continue }
            let routeId = alert.informed_entity?.first?.route_id ?? ""
            out.append(SubteAlertItem(
                line: SubteLine.line(routeId: routeId),
                text: text,
                effect: alert.effect ?? 7
            ))
        }
        return out.sorted { $0.severity < $1.severity }
    }

    // MARK: - EcoBici

    // Une stationInformation + stationStatus por station_id (en paralelo).
    func ecobiciStations() async throws -> [EcobiciStation] {
        async let infoTask = get(path: "ecobici/gbfs/stationInformation", flags: [:])
        async let statusTask = get(path: "ecobici/gbfs/stationStatus", flags: [:])
        let (infoData, statusData) = try await (infoTask, statusTask)

        let info = try decode(GbfsInfoResponse.self, infoData)
        let status = try decode(GbfsStatusResponse.self, statusData)

        var statusById: [String: GbfsStatusStation] = [:]
        for s in status.data?.stations ?? [] {
            if let id = s.station_id { statusById[id] = s }
        }

        var out: [EcobiciStation] = []
        for i in info.data?.stations ?? [] {
            guard let id = i.station_id else { continue }
            let s = statusById[id]
            let mechanical = s?.num_bikes_available_types?.mechanical ?? 0
            let ebike = s?.num_bikes_available_types?.ebike ?? 0
            let total = s?.num_bikes_available ?? (mechanical + ebike)
            let reported = s?.last_reported.map { Date(timeIntervalSince1970: TimeInterval($0)) } ?? Date()
            out.append(EcobiciStation(
                id: id,
                name: i.name ?? "",
                lat: i.lat ?? 0,
                lng: i.lon ?? 0,
                capacity: i.capacity ?? 0,
                bikesMechanical: mechanical,
                bikesEbike: ebike,
                bikesTotal: total,
                docksAvailable: s?.num_docks_available ?? 0,
                status: s?.status ?? "UNKNOWN",
                lastReported: reported
            ))
        }
        return out
    }

    // MARK: - Colectivos: posiciones GPS en vivo

    // Todos los colectivos con GPS (protobuf, sin json). Decodifica con GTFSRealtime.
    // Si 'near' está dado, ordena por cercanía y corta a maxCount (perf del mapa).
    func colectivoPositions(near: CLLocationCoordinate2D? = nil, maxCount: Int = 500) async throws -> [BusPosition] {
        let data = try await get(path: "colectivos/vehiclePositions", flags: [:], accept: "application/x-protobuf")
        var positions = parseVehiclePositions(data)
        if let near {
            let cosLat = cos(near.latitude * .pi / 180)
            func approx(_ p: BusPosition) -> Double {
                let dLat = p.coordinate.latitude - near.latitude
                let dLng = (p.coordinate.longitude - near.longitude) * cosLat
                return dLat * dLat + dLng * dLng
            }
            positions.sort { approx($0) < approx($1) }
        }
        if positions.count > maxCount { positions = Array(positions.prefix(maxCount)) }
        return positions
    }

    // MARK: - Colectivos: arribos por parada ("cuándo llega")

    // Pronóstico de una parada. OJO: hoy el backend SOAP de BA devuelve 503.
    // Detecta 503 o JSON-de-error y tira BAError.serviceUnavailable con mensaje claro.
    func colectivoArrivals(stopCode: String) async throws -> [BusArrival] {
        let data: Data
        do {
            data = try await get(path: "colectivos/forecastGTFS", flags: ["StopCode": stopCode, "json": "1"])
        } catch let APIError.http(status, _) where status == 503 {
            throw APIError.serviceUnavailable(message: Self.colectivoDownMessage)
        }
        // El backend a veces responde 200 con un cuerpo de error JSON.
        if let env = try? decoder.decode(BAErrorEnvelope.self, from: data), env.error != nil {
            throw APIError.serviceUnavailable(message: Self.colectivoDownMessage)
        }
        let resp = try decode(ForecastResponse.self, data)
        let now = Date()

        var out: [BusArrival] = []
        for entity in resp.Entity ?? [] {
            guard let linea = entity.Linea else { continue }
            let stops = linea.Estaciones ?? []
            let stop = stops.first(where: { $0.stop_id == stopCode }) ?? stops.first
            guard let stop, let epoch = stop.arrival?.time else { continue }
            let eta = Date(timeIntervalSince1970: TimeInterval(epoch))
            let secondsUntil = Int(eta.timeIntervalSince(now).rounded())
            if secondsUntil < 0 { continue }

            let lineName = ColectivoCatalog.shared.displayLine(routeId: linea.Route_Id ?? "")
            let destino = stops.last?.stop_name
            let delaySeconds = stop.arrival?.delay ?? 0
            let scheduled = eta.addingTimeInterval(TimeInterval(-delaySeconds))
            let delay = DelayLogic.status(scheduled: scheduled, estimated: eta, tolerance: subteTolerance)
            out.append(BusArrival(
                lineName: lineName,
                destino: destino,
                eta: eta,
                secondsUntil: secondsUntil,
                delay: delay
            ))
        }
        return out.sorted { $0.secondsUntil < $1.secondsUntil }
    }

    private static let colectivoDownMessage =
        "El servicio de arribos de colectivos de la Ciudad no está disponible ahora. Probá más tarde."

    // MARK: - Red

    private func get(path: String, flags: [String: String], accept: String = "application/json") async throws -> Data {
        guard BASecrets.isConfigured else { throw APIError.noToken }

        var comps = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        var items = [
            URLQueryItem(name: "client_id", value: BASecrets.clientId),
            URLQueryItem(name: "client_secret", value: BASecrets.clientSecret),
        ]
        for (k, v) in flags { items.append(URLQueryItem(name: k, value: v)) }
        comps?.queryItems = items
        guard let url = comps?.url else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.setValue(accept, forHTTPHeaderField: "Accept")

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
        if http.statusCode == 401 || http.statusCode == 403 {
            throw APIError.unauthorized
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
}

// MARK: - DTOs forecastGTFS

private struct ForecastResponse: Decodable {
    let Entity: [ForecastEntity]?
}
private struct ForecastEntity: Decodable {
    let Linea: ForecastLinea?
}
private struct ForecastLinea: Decodable {
    let Trip_Id: String?
    let Route_Id: String?
    let Direction_ID: Int?
    let Estaciones: [ForecastStop]?
}
private struct ForecastStop: Decodable {
    let stop_id: String?
    let stop_name: String?
    let arrival: ForecastTime?
}
private struct ForecastTime: Decodable {
    let time: Int?
    let delay: Int?
}

// Cuerpo de error que el gateway de BA devuelve cuando el backend SOAP cae.
private struct BAErrorEnvelope: Decodable {
    let error: String?
}

// MARK: - DTOs serviceAlerts

private struct AlertsResponse: Decodable {
    let entity: [AlertEntity]?
}
private struct AlertEntity: Decodable {
    let alert: AlertBody?
}
private struct AlertBody: Decodable {
    let informed_entity: [InformedEntity]?
    let cause: Int?
    let effect: Int?
    let header_text: TranslatedText?
}
private struct InformedEntity: Decodable {
    let route_id: String?
}
private struct TranslatedText: Decodable {
    let translation: [Translation]?
}
private struct Translation: Decodable {
    let text: String?
    let language: String?
}

// MARK: - DTOs EcoBici GBFS

private struct GbfsInfoResponse: Decodable {
    let data: GbfsInfoData?
}
private struct GbfsInfoData: Decodable {
    let stations: [GbfsInfoStation]?
}
private struct GbfsInfoStation: Decodable {
    let station_id: String?
    let name: String?
    let lat: Double?
    let lon: Double?
    let capacity: Int?
}
private struct GbfsStatusResponse: Decodable {
    let data: GbfsStatusData?
}
private struct GbfsStatusData: Decodable {
    let stations: [GbfsStatusStation]?
}
private struct GbfsStatusStation: Decodable {
    let station_id: String?
    let num_bikes_available: Int?
    let num_docks_available: Int?
    let num_bikes_available_types: GbfsBikeTypes?
    let status: String?
    let last_reported: Int?
}
private struct GbfsBikeTypes: Decodable {
    let mechanical: Int?
    let ebike: Int?
}
