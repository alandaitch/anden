import Foundation
import WidgetKit

// Arribo mínimo para el widget. El bundle del widget no tiene los JSON del catálogo,
// así que todo lo que el widget necesita viaja en este snapshot por App Group.
struct MiniArrival: Codable, Identifiable, Hashable {
    let destino: String
    let eta: Date
    let delaySeconds: Int
    let statusLabel: String
    let trackName: String?   // andén (solo tren); nil en subte/colectivo

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

    init(from s: SubteArrival) {
        self.init(
            destino: s.destinationName,
            eta: s.eta,
            delaySeconds: s.delay.delaySeconds ?? 0,
            statusLabel: s.delay.label,
            trackName: nil
        )
    }

    init(from b: BusArrivalOba) {
        let dest = b.headsign.isEmpty ? "Línea \(b.lineShort)" : "\(b.lineShort) · \(b.headsign)"
        self.init(
            destino: dest,
            eta: b.eta ?? Date().addingTimeInterval(TimeInterval(b.secondsUntil)),
            delaySeconds: 0,
            statusLabel: b.isLive ? "En vivo" : "Programado",
            trackName: nil
        )
    }
}

// Snapshot que la app escribe y el widget lee. Persiste en App Group.
struct WidgetSnapshot: Codable {
    let mode: FavoriteMode
    let refId: String          // id de la parada en su modo (tren: stationId como String)
    let stationId: Int         // solo tren (para refrescar desde el widget); 0 en otros modos
    let stationName: String
    let lineShortCode: String  // badge; "" en colectivo (se muestra ícono de bondi)
    let lineColorHex: String
    let generatedAt: Date
    let arrivals: [MiniArrival]

    static let appGroup = "group.com.alandaitch.anden"
    static let key = "widget.snapshot.v2"

    private static var store: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    // Ícono SF Symbol según el modo.
    var modeIcon: String {
        switch mode {
        case .tren, .subte: return "tram.fill"
        case .bondi: return "bus.fill"
        case .bici: return "bicycle"
        }
    }

    static func write(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        store.set(data, forKey: key)
    }

    static func read() -> WidgetSnapshot? {
        guard let data = store.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    // Segundos desde que se generó.
    var age: TimeInterval { Date().timeIntervalSince(generatedAt) }

    // Snapshot de muestra para placeholders del widget.
    static let sample = WidgetSnapshot(
        mode: .tren,
        refId: "87",
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
    // Corre en la app: toma el favorito contextual (de cualquier modo con arribos)
    // y persiste su snapshot. La app tiene catálogo y claves; el widget no.
    static func refreshFromApp() async {
        guard let fav = FavoritesStore.shared.contextualPrimary(among: [.tren, .subte, .bondi]) else {
            // Sin favorito con arribos: limpiamos para no mostrar uno viejo.
            clear()
            WidgetCenter.shared.reloadAllTimelines()
            return
        }
        if let snapshot = await buildSnapshot(for: fav) {
            write(snapshot)
        } else {
            // El fetch falló. Si el favorito CAMBIÓ, no dejamos el snapshot anterior:
            // escribimos la parada nueva sin arribos (el widget muestra "sin arribos").
            // Si es el mismo favorito, conservamos el último snapshot bueno.
            let prev = read()
            if prev?.mode != fav.mode || prev?.refId != fav.refId {
                write(placeholder(for: fav))
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    // Borra el snapshot persistido (cuando no hay ningún favorito con arribos).
    static func clear() {
        store.removeObject(forKey: key)
    }

    // Snapshot de una parada sin arribos (para no mostrar el favorito anterior).
    private static func placeholder(for fav: FavoriteItem) -> WidgetSnapshot {
        WidgetSnapshot(
            mode: fav.mode,
            refId: fav.refId,
            stationId: fav.mode == .tren ? (Int(fav.refId) ?? 0) : 0,
            stationName: fav.name,
            lineShortCode: fav.mode == .bondi ? "" : (fav.lineLabel ?? ""),
            lineColorHex: fav.lineColorHex ?? "#3A4A63",
            generatedAt: Date(),
            arrivals: []
        )
    }

    // Arma el snapshot pidiendo arribos al cliente correcto según el modo.
    private static func buildSnapshot(for fav: FavoriteItem) async -> WidgetSnapshot? {
        let color = fav.lineColorHex ?? "#3A4A63"
        let code = fav.lineLabel ?? ""
        switch fav.mode {
        case .tren:
            guard let stationId = Int(fav.refId),
                  let arrivals = try? await SofseClient.shared.arrivals(stationId: stationId, limit: 4) else { return nil }
            return WidgetSnapshot(mode: .tren, refId: fav.refId, stationId: stationId,
                                  stationName: fav.name, lineShortCode: code, lineColorHex: color,
                                  generatedAt: Date(), arrivals: arrivals.prefix(4).map(MiniArrival.init(from:)))
        case .subte:
            guard let arrivals = try? await BAClient.shared.subteArrivals(stationName: fav.name) else { return nil }
            return WidgetSnapshot(mode: .subte, refId: fav.refId, stationId: 0,
                                  stationName: fav.name, lineShortCode: code, lineColorHex: color,
                                  generatedAt: Date(), arrivals: arrivals.prefix(4).map(MiniArrival.init(from:)))
        case .bondi:
            guard let arrivals = try? await ObaClient.shared.stopArrivals(stopId: fav.refId) else { return nil }
            return WidgetSnapshot(mode: .bondi, refId: fav.refId, stationId: 0,
                                  stationName: fav.name, lineShortCode: "", lineColorHex: color,
                                  generatedAt: Date(), arrivals: arrivals.prefix(4).map(MiniArrival.init(from:)))
        case .bici:
            return nil
        }
    }

    // Corre en el widget: refresca sin catálogo. Tren y colectivo tienen fuente
    // sin clave secreta (SOFSE auto-token / OBA key `web`); subte/bici conservan
    // el snapshot que dejó la app.
    static func refreshInWidget(previous: WidgetSnapshot) async -> WidgetSnapshot? {
        switch previous.mode {
        case .tren:
            guard let arrivals = try? await SofseClient.shared.arrivals(stationId: previous.stationId, limit: 4) else { return nil }
            let line = arrivals.first?.line
            let snapshot = WidgetSnapshot(mode: .tren, refId: previous.refId, stationId: previous.stationId,
                                          stationName: previous.stationName,
                                          lineShortCode: line?.shortCode ?? previous.lineShortCode,
                                          lineColorHex: line?.colorHex ?? previous.lineColorHex,
                                          generatedAt: Date(), arrivals: arrivals.prefix(4).map(MiniArrival.init(from:)))
            write(snapshot)
            return snapshot
        case .bondi:
            guard let arrivals = try? await ObaClient.shared.stopArrivals(stopId: previous.refId) else { return nil }
            let snapshot = WidgetSnapshot(mode: .bondi, refId: previous.refId, stationId: 0,
                                          stationName: previous.stationName,
                                          lineShortCode: previous.lineShortCode, lineColorHex: previous.lineColorHex,
                                          generatedAt: Date(), arrivals: arrivals.prefix(4).map(MiniArrival.init(from:)))
            write(snapshot)
            return snapshot
        default:
            return nil
        }
    }
}
