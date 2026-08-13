import Foundation
import Observation
import CoreLocation

// Estación de subte del catálogo (subte-estaciones.json).
struct SubteStation: Identifiable, Hashable {
    let name: String
    let line: SubteLine
    let lat: Double
    let lng: Double
    let aliases: [String]

    var id: String { "\(line.routeId)-\(name)" }
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

// Catálogo embebido de estaciones de subte (108).
// Sirve para geolocalizar estaciones y cruzar con el forecast (que trae stop_name).
@Observable
final class SubteCatalog {
    static let shared = SubteCatalog()

    private(set) var all: [SubteStation] = []

    // Índice por nombre normalizado (nombre + aliases) -> estación.
    private var byNormalizedName: [String: SubteStation] = [:]

    init(bundle: Bundle = .main) {
        load(bundle: bundle)
    }

    private struct StationDTO: Decodable {
        let name: String
        let line: String
        let lat: Double
        let lng: Double
        let aliases: [String]?
    }

    private func load(bundle: Bundle) {
        let dec = JSONDecoder()
        guard let url = bundle.url(forResource: "subte-estaciones", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dtos = try? dec.decode([StationDTO].self, from: data)
        else { return }

        all = dtos.map {
            SubteStation(
                name: $0.name,
                line: SubteLine.line(routeId: $0.line),
                lat: $0.lat,
                lng: $0.lng,
                aliases: $0.aliases ?? []
            )
        }
        for st in all {
            let keys = [st.name] + st.aliases
            for k in keys {
                let norm = StationCatalog.normalize(k)
                if byNormalizedName[norm] == nil { byNormalizedName[norm] = st }
            }
        }
    }

    // Estaciones más cercanas, ordenadas por distancia. Devuelve metros reales.
    func nearest(to coordinate: CLLocationCoordinate2D, limit: Int = 5) -> [(SubteStation, CLLocationDistance)] {
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return all
            .map { ($0, CLLocation(latitude: $0.lat, longitude: $0.lng).distance(from: origin)) }
            .sorted { $0.1 < $1.1 }
            .prefix(max(0, limit))
            .map { $0 }
    }

    // Estación por nombre, matcheando nombre normalizado + aliases. nil si no matchea.
    func station(name: String) -> SubteStation? {
        byNormalizedName[StationCatalog.normalize(name)]
    }
}
