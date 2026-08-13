import SwiftUI

// Tipos de navegación e helpers compartidos del feature Subte.
// Las vistas NO montan NavigationStack propio; la integración las mete en un stack.

// Referencia Hashable para navegar a una línea de subte.
struct SubteLineRef: Hashable {
    let routeId: String

    init(routeId: String) { self.routeId = routeId }
    init(_ line: SubteLine) { self.routeId = line.routeId }

    var line: SubteLine { SubteLine.line(routeId: routeId) }
}

// Referencia Hashable para navegar al tablero de una estación dentro de una línea.
struct SubteStationRef: Hashable {
    let routeId: String
    let stationName: String

    var line: SubteLine { SubteLine.line(routeId: routeId) }
}

// Helpers de formato y color del feature Subte.
enum SubteFormat {
    // Mensaje de error en es-AR a partir de un Error de red.
    static func message(for error: Error) -> String {
        if let api = error as? APIError, let desc = api.errorDescription {
            return desc
        }
        return "Revisá tu conexión e intentá de nuevo."
    }

    // Tinte según la gravedad del efecto GTFS-rt de la alerta.
    static func tint(for alert: SubteAlertItem) -> Color {
        switch alert.effect {
        case 1, 4: return Palette.majorDelay   // sin servicio / demoras fuertes
        case 2, 6: return Palette.minorDelay   // reducido / desvío
        default:   return Palette.textSecondary
        }
    }

    // Texto corto del estado de una línea para las filas del home.
    static func shortStatus(_ alert: SubteAlertItem) -> String {
        switch alert.effect {
        case 1: return "Sin servicio"
        case 2: return "Servicio reducido"
        case 4: return "Demoras"
        case 6: return "Desvío"
        case 8: return "Estación movida"
        default: return "Con novedades"
        }
    }
}
