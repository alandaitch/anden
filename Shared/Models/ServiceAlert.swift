import Foundation

// Alerta de servicio. Viaja embebida en /infraestructura/gerencias y /infraestructura/ramales.
struct ServiceAlert: Identifiable, Hashable {
    let id: Int
    let lineId: Int?
    let ramalId: Int?
    let causeGTFS: String
    let effectGTFS: String
    let content: String
    let criticality: Int
    let validFrom: Date?
    let validUntil: Date?

    // Mapea causa/efecto GTFS a SF Symbols. El efecto manda sobre la causa.
    var iconSystemName: String {
        switch effectGTFS {
        case "NO_SERVICE":         return "xmark.octagon.fill"
        case "SIGNIFICANT_DELAYS": return "clock.badge.exclamationmark.fill"
        case "REDUCED_SERVICE":    return "tram.fill.tunnel"
        case "DETOUR":             return "arrow.triangle.branch"
        case "STOP_MOVED":         return "mappin.slash"
        default: break
        }
        switch causeGTFS {
        case "ACCIDENT":          return "exclamationmark.triangle.fill"
        case "TECHNICAL_PROBLEM": return "wrench.and.screwdriver.fill"
        case "STRIKE":            return "person.2.slash.fill"
        case "MAINTENANCE":       return "hammer.fill"
        case "WEATHER":           return "cloud.bolt.rain.fill"
        default:                  return "exclamationmark.circle.fill"
        }
    }
}
