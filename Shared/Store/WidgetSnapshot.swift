import Foundation
import WidgetKit

// Arribo mínimo para el widget. El bundle del widget no tiene los JSON del catálogo,
// así que todo lo que el widget necesita viaja en este snapshot por App Group.
struct MiniArrival: Codable, Identifiable, Hashable {
    let destino: String
    let eta: Date
    let delaySeconds: Int
    let statusLabel: String
    let trackName: String?

    var id: String { "\(destino)-\(Int(eta.timeIntervalSince1970))" }
}

extension MiniArrival {
    init(from a: Arrival) {
        self.init(
            destino: a.destinationName,
            eta: a.estimated ?? Date().addingTimeInterval(TimeInterval(a.secondsUntil)),
            delaySeconds: a.delay.delaySeconds ?? 0,
            statusLabel: a.delay.label,
            trackName: a.trackName
        )
    }
}

// Snapshot que la app escribe y el widget lee. Persiste en App Group.
struct WidgetSnapshot: Codable {
    let stationId: Int
    let stationName: String
    let lineShortCode: String
    let lineColorHex: String
    let generatedAt: Date
    let arrivals: [MiniArrival]

    static let appGroup = "group.com.alandaitch.anden"
    static let key = "widget.snapshot.v1"

    private static var store: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    // Persiste el snapshot en App Group.
    static func write(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        store.set(data, forKey: key)
    }

    // Lee el último snapshot persistido.
    static func read() -> WidgetSnapshot? {
        guard let data = store.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    // Segundos desde que se generó.
    var age: TimeInterval { Date().timeIntervalSince(generatedAt) }

    // Snapshot de muestra para placeholders del widget.
    static let sample = WidgetSnapshot(
        stationId: 87,
        stationName: "Retiro Mitre",
        lineShortCode: "MI",
        lineColorHex: "#1E7FD4",
        generatedAt: Date(),
        arrivals: [
            MiniArrival(destino: "Tigre", eta: Date().addingTimeInterval(180), delaySeconds: 0, statusLabel: "En horario", trackName: "2"),
            MiniArrival(destino: "Tigre", eta: Date().addingTimeInterval(720), delaySeconds: 240, statusLabel: "+4 min", trackName: "3"),
            MiniArrival(destino: "Bartolomé Mitre", eta: Date().addingTimeInterval(1140), delaySeconds: 0, statusLabel: "En horario", trackName: "1")
        ]
    )
}

extension WidgetSnapshot {
    // Corre en la app: toma la estación contextual, pide arribos y persiste el snapshot.
    // Requiere el catálogo cargado (target app), no el del widget.
    static func refreshFromApp() async {
        guard let station = FavoritesStore.shared.contextualPrimary() else {
            // Sin favoritos: no hay estación que mostrar. Dejamos el snapshot como está.
            WidgetCenter.shared.reloadAllTimelines()
            return
        }
        let line = station.line
        do {
            let arrivals = try await SofseClient.shared.arrivals(stationId: station.id, limit: 4)
            let snapshot = WidgetSnapshot(
                stationId: station.id,
                stationName: station.nombre,
                lineShortCode: line.shortCode,
                lineColorHex: line.colorHex,
                generatedAt: Date(),
                arrivals: arrivals.prefix(4).map(MiniArrival.init(from:))
            )
            write(snapshot)
        } catch {
            // Falló la red: conservamos el snapshot previo.
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    // Corre en el widget: refresca solo con el stationId conocido, sin catálogo.
    // Conserva nombre y línea del snapshot previo como fallback.
    static func refreshInWidget(stationId: Int, stationName: String, fallbackShortCode: String, fallbackColorHex: String) async -> WidgetSnapshot? {
        guard let arrivals = try? await SofseClient.shared.arrivals(stationId: stationId, limit: 4) else {
            return nil
        }
        let line = arrivals.first?.line
        let snapshot = WidgetSnapshot(
            stationId: stationId,
            stationName: stationName,
            lineShortCode: line?.shortCode ?? fallbackShortCode,
            lineColorHex: line?.colorHex ?? fallbackColorHex,
            generatedAt: Date(),
            arrivals: arrivals.prefix(4).map(MiniArrival.init(from:))
        )
        write(snapshot)
        return snapshot
    }
}
