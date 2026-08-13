import SwiftUI

// Estado de demora de un arribo. minor vs major se decide con la tolerancia del ramal.
enum DelayStatus: Equatable, Hashable {
    case onTime
    case early(seconds: Int)
    case minor(seconds: Int)
    case major(seconds: Int)
    case noData
    case cancelled

    private static func minutes(_ seconds: Int) -> Int {
        Int((Double(abs(seconds)) / 60).rounded())
    }

    var label: String {
        switch self {
        case .onTime:            return "En horario"
        case .early(let s):      return "-\(Self.minutes(s)) min"
        case .minor(let s):      return "+\(Self.minutes(s)) min"
        case .major(let s):      return "+\(Self.minutes(s)) min"
        case .noData:            return "Sin datos"
        case .cancelled:         return "Cancelado"
        }
    }

    var shortLabel: String {
        switch self {
        case .onTime:            return "En hora"
        case .early(let s):      return "-\(Self.minutes(s))"
        case .minor(let s):      return "+\(Self.minutes(s))"
        case .major(let s):      return "+\(Self.minutes(s))"
        case .noData:            return "S/D"
        case .cancelled:         return "Canc."
        }
    }

    var color: Color {
        switch self {
        case .onTime, .early:    return Palette.onTime
        case .minor:             return Palette.minorDelay
        case .major, .cancelled: return Palette.majorDelay
        case .noData:            return Palette.noData
        }
    }

    // Segundos de demora con signo (negativo = adelantado). nil si no hay dato.
    var delaySeconds: Int? {
        switch self {
        case .early(let s):  return -s
        case .minor(let s):  return s
        case .major(let s):  return s
        case .onTime:        return 0
        case .noData, .cancelled: return nil
        }
    }
}
