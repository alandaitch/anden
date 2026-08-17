import Foundation
import Observation
import CoreLocation

// Catálogo embebido de líneas y paradas de colectivos.
// Carga colectivos-lineas.json (1052) + colectivos-paradas.json (42805) del bundle.
// OJO: solo ~32% de los route_id del feed en vivo matchean el catálogo (GTFS 2019).
@Observable
final class ColectivoCatalog {
    static let shared = ColectivoCatalog()

    private(set) var lines: [BusLine] = []
    private(set) var stops: [BusStop] = []

    private var lineByRouteId: [String: BusLine] = [:]

    init(bundle: Bundle = .main) {
        load(bundle: bundle)
    }

    private struct LineDTO: Decodable {
        let routeId: String
        let shortName: String
        let longName: String
    }

    private struct StopDTO: Decodable {
        let code: String
        let name: String
        let lat: Double
        let lng: Double
    }

    private func load(bundle: Bundle) {
        let dec = JSONDecoder()
        if let url = bundle.url(forResource: "colectivos-lineas", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let dtos = try? dec.decode([LineDTO].self, from: data) {
            lines = dtos.map { BusLine(routeId: $0.routeId, shortName: $0.shortName, longName: $0.longName) }
            lineByRouteId = Dictionary(lines.map { ($0.routeId, $0) }, uniquingKeysWith: { a, _ in a })
        }
        if let url = bundle.url(forResource: "colectivos-paradas", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let dtos = try? dec.decode([StopDTO].self, from: data) {
            stops = dtos.map { BusStop(code: $0.code, name: $0.name, lat: $0.lat, lng: $0.lng) }
        }
    }

    // Línea por route_id. nil si no matchea (esperado en ~68% de los casos).
    func line(routeId: String) -> BusLine? { lineByRouteId[routeId] }

    // Número de línea para mostrar. shortName si matchea, si no el propio route_id.
    func displayLine(routeId: String) -> String {
        lineByRouteId[routeId]?.shortName ?? routeId
    }

    // Nombre "lindo" de la parada más cercana a una coord, dentro de maxMeters.
    // Arregla los nombres crudos de OneBusAway ("359 CALLAO AV." -> "Av. Callao 359").
    // Un solo barrido lineal, sin ordenar. nil si no matchea.
    func nearestStopName(to coordinate: CLLocationCoordinate2D, maxMeters: CLLocationDistance = 40) -> String? {
        guard !stops.isEmpty else { return nil }
        let cosLat = cos(coordinate.latitude * .pi / 180)
        var best: BusStop?
        var bestD = Double.greatestFiniteMagnitude
        for s in stops {
            let dLat = s.lat - coordinate.latitude
            let dLng = (s.lng - coordinate.longitude) * cosLat
            let d = dLat * dLat + dLng * dLng
            if d < bestD { bestD = d; best = s }
        }
        guard let b = best else { return nil }
        let meters = CLLocation(latitude: b.lat, longitude: b.lng)
            .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
        return meters <= maxMeters ? b.name : nil
    }

    // Paradas más cercanas, ordenadas por distancia. Devuelve metros reales.
    // Prefiltra por distancia equirectangular barata para no crear 42805 CLLocation.
    func nearbyStops(to coordinate: CLLocationCoordinate2D, limit: Int = 12) -> [(BusStop, CLLocationDistance)] {
        let cosLat = cos(coordinate.latitude * .pi / 180)
        func approx(_ s: BusStop) -> Double {
            let dLat = s.lat - coordinate.latitude
            let dLng = (s.lng - coordinate.longitude) * cosLat
            return dLat * dLat + dLng * dLng
        }
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return stops
            .sorted { approx($0) < approx($1) }
            .prefix(max(0, limit))
            .map { ($0, CLLocation(latitude: $0.lat, longitude: $0.lng).distance(from: origin)) }
    }
}
