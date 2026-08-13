import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case http(status: Int, body: String?)
    case unauthorized
    case decoding(Error)
    case transport(Error)
    case noToken
    case serviceUnavailable(message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidURL:               return "URL inválida."
        case .http(let status, _):      return "Error de red (\(status))."
        case .unauthorized:             return "Autenticación fallida."
        case .decoding:                 return "No se pudo leer la respuesta."
        case .transport:                return "Sin conexión con el servidor."
        case .noToken:                  return "No hay token disponible."
        case .serviceUnavailable(let m): return m ?? "Servicio no disponible."
        }
    }
}

// Alias para el cliente de la API BA. Comparte los casos de APIError.
typealias BAError = APIError

// Parseo de fechas de la API. Dos esquemas: ISO UTC (con Z) y alertas (local, sin Z).
enum SofseDate {
    private static let isoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // ISO UTC con sufijo Z. Ej "2026-08-12T20:53:30.000Z".
    static func iso(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        return isoFrac.date(from: s) ?? isoPlain.date(from: s)
    }

    private static let alertFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    // Fecha de alerta: "YYYY-MM-DD HH:MM:SS" en hora local, sin Z.
    static func alert(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        return alertFormatter.date(from: s)
    }
}
