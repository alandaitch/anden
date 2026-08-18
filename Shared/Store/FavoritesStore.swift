import Foundation
import Observation
import CoreLocation

enum FavoriteRole: String, Codable, Hashable {
    case none, home, work
}

// Modo de transporte de un favorito.
enum FavoriteMode: String, Codable, Hashable {
    case tren, subte, bondi, bici
}

// Favorito de cualquier modo. Guarda todo lo necesario para mostrarlo y navegar,
// sin depender de catálogos (bondi y bici no tienen catálogo estático embebido).
struct FavoriteItem: Codable, Identifiable, Hashable {
    let mode: FavoriteMode
    let refId: String          // id estable por modo
    var name: String
    var lat: Double
    var lng: Double
    var lineLabel: String?     // texto del badge de línea (nil en bondi/bici)
    var lineColorHex: String?  // color del badge
    var routeId: String?       // subte: routeId para navegar
    var role: FavoriteRole
    var addedAt: Date

    var id: String { "\(mode.rawValue):\(refId)" }
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

extension FavoriteItem {
    static func train(_ s: Station) -> FavoriteItem {
        FavoriteItem(mode: .tren, refId: String(s.id), name: s.nombre, lat: s.lat, lng: s.lng,
                     lineLabel: s.line.shortCode, lineColorHex: s.line.colorHex, routeId: nil,
                     role: .none, addedAt: Date())
    }
    static func subte(_ s: SubteStation) -> FavoriteItem {
        FavoriteItem(mode: .subte, refId: s.id, name: s.name, lat: s.lat, lng: s.lng,
                     lineLabel: s.line.letra, lineColorHex: s.line.colorHex, routeId: s.line.routeId,
                     role: .none, addedAt: Date())
    }
    static func bondi(_ r: ObaStopRef) -> FavoriteItem {
        FavoriteItem(mode: .bondi, refId: r.stopId, name: r.name, lat: r.lat, lng: r.lng,
                     lineLabel: nil, lineColorHex: nil, routeId: nil, role: .none, addedAt: Date())
    }
    static func bici(_ s: EcobiciStation) -> FavoriteItem {
        FavoriteItem(mode: .bici, refId: s.id, name: s.displayName, lat: s.lat, lng: s.lng,
                     lineLabel: nil, lineColorHex: nil, routeId: nil, role: .none, addedAt: Date())
    }
}

// Formato viejo (solo trenes) para migrar sin perder favoritos guardados.
private struct LegacyFavoriteStation: Codable {
    let stationId: Int
    var role: FavoriteRole
    var addedAt: Date
}

// Favoritos multi-modo con rol de contexto. Persiste en App Group.
@Observable
final class FavoritesStore {
    static let shared = FavoritesStore()

    private let defaults: UserDefaults
    private let key = "favorites.v2"
    private let legacyKey = "favorites.v1"
    private let catalog: StationCatalog

    private(set) var items: [FavoriteItem] = []

    init(defaults: UserDefaults? = nil, catalog: StationCatalog = .shared) {
        self.defaults = defaults ?? (UserDefaults(suiteName: "group.com.alandaitch.anden") ?? .standard)
        self.catalog = catalog
        load()
    }

    private func load() {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([FavoriteItem].self, from: data) {
            items = decoded
            return
        }
        migrateLegacy()
    }

    // Migra los favoritos v1 (solo trenes) al modelo nuevo y persiste en v2.
    private func migrateLegacy() {
        guard let data = defaults.data(forKey: legacyKey),
              let old = try? JSONDecoder().decode([LegacyFavoriteStation].self, from: data) else { return }
        items = old.compactMap { legacy in
            guard let st = catalog.station(id: legacy.stationId) else { return nil }
            return FavoriteItem(mode: .tren, refId: String(legacy.stationId),
                                name: st.nombre, lat: st.lat, lng: st.lng,
                                lineLabel: st.line.shortCode, lineColorHex: st.line.colorHex,
                                routeId: nil, role: legacy.role, addedAt: legacy.addedAt)
        }
        if !items.isEmpty { persist() }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: key)
        }
    }

    // MARK: - API por (mode, refId)

    func isFavorite(_ mode: FavoriteMode, _ refId: String) -> Bool {
        items.contains { $0.mode == mode && $0.refId == refId }
    }

    func toggle(_ item: FavoriteItem) {
        if let idx = items.firstIndex(where: { $0.mode == item.mode && $0.refId == item.refId }) {
            items.remove(at: idx)
        } else {
            items.append(item)
        }
        persist()
    }

    func remove(_ mode: FavoriteMode, _ refId: String) {
        items.removeAll { $0.mode == mode && $0.refId == refId }
        persist()
    }

    // Fija home/work sobre un favorito existente.
    func setRole(_ role: FavoriteRole, _ mode: FavoriteMode, _ refId: String) {
        guard let idx = items.firstIndex(where: { $0.mode == mode && $0.refId == refId }) else { return }
        items[idx].role = role
        persist()
    }

    func role(_ mode: FavoriteMode, _ refId: String) -> FavoriteRole {
        items.first { $0.mode == mode && $0.refId == refId }?.role ?? .none
    }

    // MARK: - Consumidores

    // Favorito "del momento": home a la mañana (4-12), work a la tarde (12-22).
    // Si no hay rol para la franja, el primero agregado. `among` limita los modos
    // (el widget pide solo modos con arribos: tren/subte/bondi).
    func contextualPrimary(now: Date = Date(), among modes: Set<FavoriteMode>? = nil) -> FavoriteItem? {
        let pool = modes.map { m in items.filter { m.contains($0.mode) } } ?? items
        let hour = Calendar.current.component(.hour, from: now)
        let preferred: FavoriteRole = (hour >= 4 && hour < 12) ? .home : ((hour >= 12 && hour < 22) ? .work : .none)
        if preferred != .none, let fav = pool.first(where: { $0.role == preferred }) {
            return fav
        }
        return pool.first
    }

    // Estaciones de tren favoritas resueltas (para notificaciones de demora, que hoy son solo tren).
    var trainStations: [Station] {
        items.filter { $0.mode == .tren }.compactMap { catalog.station(id: Int($0.refId) ?? -1) }
    }
}
