import Foundation
import CoreLocation

// Cliente de la API OneBusAway de cuandosubo (SUBE). Da arribos de colectivo en vivo.
// La key `web` es pública (sale del cliente web oficial), no es un secreto.
// Timeout 15s. Nunca cuelga: degrada con throws claro.
actor ObaClient {
    static let shared = ObaClient()

    private let base = "https://cuandosubo.sube.gob.ar/onebusaway-api-webapp/api/where"
    private let key = "web"
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let cfg = URLSessionConfiguration.default
            cfg.timeoutIntervalForRequest = 15
            cfg.timeoutIntervalForResource = 15
            cfg.waitsForConnectivity = false
            self.session = URLSession(configuration: cfg)
        }
    }

    // MARK: - Líneas cercanas con "cuándo llega"

    // Algoritmo de 4 pasos:
    // 1. Paradas cercanas (stops-for-location, radius ~500m).
    // 2. Arribos de las ~maxStops paradas más cercanas, en paralelo (límite 5).
    // 3. Agrupar por (routeShortName + tripHeadsign), quedarse con el próximo futuro.
    // 4. Ordenar por minutos.
    func nearbyBusLines(near: CLLocationCoordinate2D, radius: Int = 500, maxStops: Int = 10) async throws -> [BusLineNearby] {
        let stops = try await stopsForLocation(near: near, radius: radius)
        guard !stops.isEmpty else { return [] }

        let origin = CLLocation(latitude: near.latitude, longitude: near.longitude)
        let nearest: [ObaStopDTO] = stops
            .map { ($0, CLLocation(latitude: $0.latValue, longitude: $0.lonValue).distance(from: origin)) }
            .sorted { $0.1 < $1.1 }
            .prefix(max(0, maxStops))
            .map { $0.0 }

        let now = Date()
        var byKey: [String: BusLineNearby] = [:]

        await withTaskGroup(of: [(stop: ObaStopDTO, arrival: ObaArrivalDTO)].self) { group in
            var index = 0
            let maxConcurrent = 5

            func addNext() {
                guard index < nearest.count else { return }
                let stop = nearest[index]
                index += 1
                group.addTask {
                    let arrivals = (try? await self.arrivalsForStop(stopId: stop.id)) ?? []
                    return arrivals.map { (stop, $0) }
                }
            }

            for _ in 0..<min(maxConcurrent, nearest.count) { addNext() }

            while let batch = await group.next() {
                for pair in batch {
                    guard let line = Self.makeLine(pair.arrival, stop: pair.stop, now: now) else { continue }
                    let key = "\(line.lineShort)|\(line.headsign)"
                    if let existing = byKey[key], existing.secondsUntil <= line.secondsUntil { continue }
                    byKey[key] = line
                }
                addNext()
            }
        }

        return byKey.values.sorted { $0.secondsUntil < $1.secondsUntil }
    }

    // MARK: - Arribos de una parada

    func stopArrivals(stopId: String) async throws -> [BusArrivalOba] {
        let arrivals = try await arrivalsForStop(stopId: stopId)
        let now = Date()

        var out: [BusArrivalOba] = []
        for a in arrivals {
            guard let ms = Self.chosenEpochMs(a) else { continue }
            let eta = Date(timeIntervalSince1970: ms / 1000)
            let secs = Int(eta.timeIntervalSince(now).rounded())
            if secs < -45 { continue }
            out.append(BusArrivalOba(
                lineShort: a.routeShortName ?? "",
                headsign: a.tripHeadsign ?? "",
                eta: eta,
                secondsUntil: max(0, secs),
                isLive: Self.isLive(a),
                vehicleCoordinate: Self.liveVehicleCoordinate(a)
            ))
        }
        return out.sorted { $0.secondsUntil < $1.secondsUntil }
    }

    // Posición GPS del coche SOLO si OBA la da en vivo (tripStatus.predicted).
    // Prefiere position (proyectada al recorrido); si viene inválida (0,0 o nula),
    // cae al último GPS crudo. Valida cada candidato por separado, no solo presencia.
    private static func liveVehicleCoordinate(_ a: ObaArrivalDTO) -> CLLocationCoordinate2D? {
        guard let ts = a.tripStatus, (ts.predicted ?? false) else { return nil }
        return validCoord(ts.position) ?? validCoord(ts.lastKnownLocation)
    }

    private static func validCoord(_ c: ObaCoordDTO?) -> CLLocationCoordinate2D? {
        guard let lat = c?.lat, let lon = c?.lon, lat != 0, lon != 0 else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    // MARK: - Helpers de arribo

    // Épocha (ms) elegida: predicha si hay dato vivo, si no la programada. nil si ninguna.
    private static func chosenEpochMs(_ a: ObaArrivalDTO) -> Double? {
        if isLive(a), let p = a.predictedArrivalTime, p > 0 { return p }
        if let s = a.scheduledArrivalTime, s > 0 { return s }
        return nil
    }

    private static func isLive(_ a: ObaArrivalDTO) -> Bool {
        (a.predicted ?? false) && (a.predictedArrivalTime ?? 0) > 0
    }

    private static func makeLine(_ a: ObaArrivalDTO, stop: ObaStopDTO, now: Date) -> BusLineNearby? {
        guard let ms = chosenEpochMs(a) else { return nil }
        let eta = Date(timeIntervalSince1970: ms / 1000)
        let secs = Int(eta.timeIntervalSince(now).rounded())
        guard secs >= 0 else { return nil }
        return BusLineNearby(
            lineShort: a.routeShortName ?? "",
            headsign: a.tripHeadsign ?? "",
            eta: eta,
            secondsUntil: secs,
            isLive: isLive(a),
            stopName: stop.nameValue,
            stopId: stop.id,
            stopCoordinate: CLLocationCoordinate2D(latitude: stop.latValue, longitude: stop.lonValue)
        )
    }

    // MARK: - Endpoints crudos

    private func stopsForLocation(near: CLLocationCoordinate2D, radius: Int) async throws -> [ObaStopDTO] {
        let data = try await get(path: "stops-for-location.json", query: [
            "lat": String(near.latitude),
            "lon": String(near.longitude),
            "radius": String(radius),
        ])
        let resp = try decode(ObaStopsResponse.self, data)
        return resp.data?.list ?? []
    }

    private func arrivalsForStop(stopId: String) async throws -> [ObaArrivalDTO] {
        let encoded = stopId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? stopId
        let data = try await get(path: "arrivals-and-departures-for-stop/\(encoded).json", query: [:])
        let resp = try decode(ObaArrivalsResponse.self, data)
        return resp.data?.entry?.arrivalsAndDepartures ?? []
    }

    // MARK: - Red

    private func get(path: String, query: [String: String]) async throws -> Data {
        guard var comps = URLComponents(string: "\(base)/\(path)") else { throw APIError.invalidURL }
        var items = [URLQueryItem(name: "key", value: key)]
        for (k, v) in query { items.append(URLQueryItem(name: k, value: v)) }
        comps.queryItems = items
        guard let url = comps.url else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")

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

// MARK: - DTOs OneBusAway

private struct ObaStopsResponse: Decodable {
    let data: ObaStopsData?
}
private struct ObaStopsData: Decodable {
    let list: [ObaStopDTO]?
}
struct ObaStopDTO: Decodable {
    let id: String
    let code: String?
    let name: String?
    let lat: Double?
    let lon: Double?
    let routeIds: [String]?

    var nameValue: String { name ?? code ?? id }
    var latValue: Double { lat ?? 0 }
    var lonValue: Double { lon ?? 0 }
}

private struct ObaArrivalsResponse: Decodable {
    let data: ObaArrivalsData?
}
private struct ObaArrivalsData: Decodable {
    let entry: ObaArrivalsEntry?
}
private struct ObaArrivalsEntry: Decodable {
    let arrivalsAndDepartures: [ObaArrivalDTO]?
}
struct ObaArrivalDTO: Decodable {
    let routeShortName: String?
    let tripHeadsign: String?
    let predicted: Bool?
    let predictedArrivalTime: Double?
    let scheduledArrivalTime: Double?
    let distanceFromStop: Double?
    let stopId: String?
    let tripStatus: ObaTripStatusDTO?
}

// Estado del viaje del coche. position siempre viene, pero es GPS real
// solo cuando predicted == true (si no, es una interpolación por horario).
struct ObaTripStatusDTO: Decodable {
    let predicted: Bool?
    let position: ObaCoordDTO?
    let lastKnownLocation: ObaCoordDTO?
    let vehicleId: String?
}

struct ObaCoordDTO: Decodable {
    let lat: Double?
    let lon: Double?
}
