import Foundation

// Parada del recorrido de un servicio.
struct RouteStop: Identifiable, Hashable {
    let stationId: Int
    let name: String
    let order: Int
    let scheduled: Date?
    let estimated: Date?
    let trackName: String?
    let hasPassed: Bool

    var id: Int { order }
}
