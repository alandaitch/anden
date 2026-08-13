import Foundation

// Cálculo de demora. demora = estimada - programada. Ver api-reference sección 7.
enum DelayLogic {
    static let defaultTolerance = 359
    static let earlyThreshold = 60 // segundos adelantado para marcar "early"

    static func status(
        scheduled: Date?,
        estimated: Date?,
        secondsUntil: Int = 0,
        serverNow: Date? = nil,
        tolerance: Int = defaultTolerance,
        isCancelled: Bool = false
    ) -> DelayStatus {
        if isCancelled { return .cancelled }
        // Sin estimada no hay predicción en vivo. No asumir 0. Ver sección 7.
        guard let estimated, let scheduled else { return .noData }
        let delay = Int(estimated.timeIntervalSince(scheduled).rounded())
        if delay < -earlyThreshold { return .early(seconds: -delay) }
        if delay <= tolerance { return .onTime }
        if delay <= tolerance * 2 { return .minor(seconds: delay) }
        return .major(seconds: delay)
    }
}
