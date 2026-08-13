import Foundation

// Tolerancia de puntualidad del subte (segundos). Más chica que la del tren.
let subteTolerance = 120

// Una parada dentro del recorrido de un tren de subte.
struct SubteStop: Identifiable, Hashable {
    let stopId: String
    let name: String
    let eta: Date
    let delaySeconds: Int
    var delay: DelayStatus

    var id: String { stopId }

    // Calcula el estado de demora reusando DelayLogic del core.
    // scheduled = eta - delaySeconds; estimated = eta.
    init(stopId: String, name: String, eta: Date, delaySeconds: Int, tolerance: Int = subteTolerance) {
        self.stopId = stopId
        self.name = name
        self.eta = eta
        self.delaySeconds = delaySeconds
        let scheduled = eta.addingTimeInterval(TimeInterval(-delaySeconds))
        self.delay = DelayLogic.status(
            scheduled: scheduled,
            estimated: eta,
            tolerance: tolerance
        )
    }
}

// Un tren de subte (viaje) con sus paradas restantes.
struct SubteTrip: Hashable {
    let line: SubteLine
    let direction: Int      // Direction_ID (0/1)
    let stops: [SubteStop]
}

// Arribo para el tablero de una estación.
struct SubteArrival: Identifiable, Hashable {
    let line: SubteLine
    let direction: Int
    let destinationName: String
    let eta: Date
    let secondsUntil: Int
    let delay: DelayStatus

    var id: String { "\(line.routeId)-\(direction)-\(Int(eta.timeIntervalSince1970))-\(destinationName)" }
}

// Alerta de estado de servicio del subte.
struct SubteAlertItem: Identifiable, Hashable {
    let line: SubteLine
    let text: String
    let effect: Int         // GTFS-rt: 1 NO_SERVICE, 2 REDUCED, 4 DELAYS, 6 DETOUR, 7 OTHER, 8 STOP_MOVED

    var id: String { "\(line.routeId)-\(effect)-\(text.hashValue)" }

    // SF Symbol según el efecto GTFS-rt.
    var iconSystemName: String {
        switch effect {
        case 1: return "xmark.octagon.fill"                 // NO_SERVICE
        case 2: return "tram.fill.tunnel"                   // REDUCED_SERVICE
        case 4: return "clock.badge.exclamationmark.fill"   // SIGNIFICANT_DELAYS
        case 6: return "arrow.triangle.branch"              // DETOUR
        case 8: return "mappin.slash"                       // STOP_MOVED
        default: return "exclamationmark.circle.fill"       // OTHER_EFFECT
        }
    }

    // Orden de severidad para ordenar alertas. Menor = más grave.
    var severity: Int {
        switch effect {
        case 1: return 0    // NO_SERVICE
        case 4: return 1    // SIGNIFICANT_DELAYS
        case 2: return 2    // REDUCED_SERVICE
        case 6: return 3    // DETOUR
        case 8: return 4    // STOP_MOVED
        default: return 5   // OTHER
        }
    }
}
