import Foundation
import Observation
import CoreLocation

// Catálogo embebido de estaciones y ramales. Carga estaciones.json + lineas.json del bundle.
@Observable
final class StationCatalog {
    static let shared = StationCatalog()

    private(set) var all: [Station] = []
    private(set) var lines: [TrainLine] = TrainLine.all

    private var stationsById: [Int: Station] = [:]
    private var ramalsById: [Int: Ramal] = [:]

    init(bundle: Bundle = .main) {
        load(bundle: bundle)
    }

    private struct LineFile: Decodable {
        let id: Int
        let nombre: String
        let ramales: [Ramal]
    }

    private func load(bundle: Bundle) {
        let dec = JSONDecoder()
        if let url = bundle.url(forResource: "estaciones", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let stations = try? dec.decode([Station].self, from: data) {
            all = stations
            stationsById = Dictionary(stations.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        }
        if let url = bundle.url(forResource: "lineas", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let files = try? dec.decode([LineFile].self, from: data) {
            for f in files {
                for r in f.ramales { ramalsById[r.id] = r }
            }
        }
    }

    func station(id: Int) -> Station? { stationsById[id] }

    func ramal(id: Int) -> Ramal? { ramalsById[id] }

    // Substring sin acentos. Prioriza enRamalPublico y tieneArribosHoy.
    func search(_ query: String) -> [Station] {
        let q = Self.normalize(query)
        guard !q.isEmpty else { return [] }
        return all
            .filter { $0.visibleEnApp && Self.normalize($0.nombre).contains(q) }
            .sorted { a, b in
                let ra = (a.enRamalPublico ? 2 : 0) + (a.tieneArribosHoy ? 1 : 0)
                let rb = (b.enRamalPublico ? 2 : 0) + (b.tieneArribosHoy ? 1 : 0)
                if ra != rb { return ra > rb }
                return a.nombre.localizedCaseInsensitiveCompare(b.nombre) == .orderedAscending
            }
    }

    // Estaciones más cercanas con servicio real, ordenadas por distancia.
    func nearest(to coordinate: CLLocationCoordinate2D, limit: Int = 5) -> [(Station, CLLocationDistance)] {
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return all
            .filter { $0.enRamalPublico }
            .map { ($0, CLLocation(latitude: $0.lat, longitude: $0.lng).distance(from: origin)) }
            .sorted { $0.1 < $1.1 }
            .prefix(limit)
            .map { $0 }
    }

    static func normalize(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
