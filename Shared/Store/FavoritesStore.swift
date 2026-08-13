import Foundation
import Observation

enum FavoriteRole: String, Codable, Hashable {
    case none, home, work
}

struct FavoriteStation: Codable, Identifiable, Hashable {
    let stationId: Int
    var role: FavoriteRole
    var addedAt: Date

    var id: Int { stationId }
}

// Favoritos con rol de contexto. Persiste en App Group.
@Observable
final class FavoritesStore {
    static let shared = FavoritesStore()

    private let defaults: UserDefaults
    private let key = "favorites.v1"
    private let catalog: StationCatalog

    private(set) var items: [FavoriteStation] = []

    init(defaults: UserDefaults? = nil, catalog: StationCatalog = .shared) {
        self.defaults = defaults ?? (UserDefaults(suiteName: "group.com.alandaitch.anden") ?? .standard)
        self.catalog = catalog
        load()
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([FavoriteStation].self, from: data) else { return }
        items = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: key)
        }
    }

    func isFavorite(_ stationId: Int) -> Bool {
        items.contains { $0.stationId == stationId }
    }

    func toggle(_ stationId: Int) {
        if let idx = items.firstIndex(where: { $0.stationId == stationId }) {
            items.remove(at: idx)
        } else {
            items.append(FavoriteStation(stationId: stationId, role: .none, addedAt: Date()))
        }
        persist()
    }

    func setRole(_ role: FavoriteRole, for stationId: Int) {
        if let idx = items.firstIndex(where: { $0.stationId == stationId }) {
            items[idx].role = role
        } else {
            items.append(FavoriteStation(stationId: stationId, role: role, addedAt: Date()))
        }
        persist()
    }

    func role(for stationId: Int) -> FavoriteRole {
        items.first { $0.stationId == stationId }?.role ?? .none
    }

    // Estaciones resueltas contra el catálogo, en orden de agregado.
    var favorites: [Station] {
        items.compactMap { catalog.station(id: $0.stationId) }
    }

    // Home a la mañana (4-12), work a la tarde (12-22). Si no hay roles, el primero.
    func contextualPrimary(now: Date = Date()) -> Station? {
        let hour = Calendar.current.component(.hour, from: now)
        let preferred: FavoriteRole = (hour >= 4 && hour < 12) ? .home : ((hour >= 12 && hour < 22) ? .work : .none)
        if preferred != .none, let fav = items.first(where: { $0.role == preferred }) {
            return catalog.station(id: fav.stationId)
        }
        return favorites.first
    }
}
