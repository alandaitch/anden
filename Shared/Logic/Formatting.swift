import Foundation

// Helpers de formateo para la UI, es-AR.
enum Formatting {

    // "ahora" / "llegando" / "en X min".
    static func etaText(secondsUntil: Int) -> String {
        if secondsUntil <= 30 { return "ahora" }
        if secondsUntil < 90 { return "llegando" }
        let mins = Int((Double(secondsUntil) / 60).rounded())
        return "en \(mins) min"
    }

    // Minutos enteros hasta el arribo, piso en 0.
    static func minutesUntil(secondsUntil: Int) -> Int {
        max(0, Int((Double(secondsUntil) / 60).rounded(.down)))
    }

    // "a 320 m" / "a 1,2 km" (decimal con coma).
    static func distanceText(meters: Double) -> String {
        if meters < 1000 {
            return "a \(Int(meters.rounded())) m"
        }
        let km = meters / 1000
        let s = String(format: "%.1f", km).replacingOccurrences(of: ".", with: ",")
        return "a \(s) km"
    }

    // Hora local de Buenos Aires, formato HH:mm.
    private static let clockFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_AR")
        f.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")
        f.dateFormat = "HH:mm"
        return f
    }()

    static func clock(_ date: Date?) -> String {
        guard let date else { return "--:--" }
        return clockFormatter.string(from: date)
    }
}
