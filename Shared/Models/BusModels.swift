import SwiftUI
import CoreLocation

// Posición GPS en vivo de un colectivo (del feed vehiclePositions).
struct BusPosition: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let routeId: String?
    let bearing: Double?
    let interno: String?
    let patente: String?
}

// Parada de colectivo del catálogo (colectivos-paradas.json).
struct BusStop: Identifiable, Hashable {
    let code: String
    let name: String
    let lat: Double
    let lng: Double

    var id: String { code }
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

// Arribo pronosticado en una parada (forecastGTFS por StopCode).
struct BusArrival: Identifiable {
    let lineName: String
    let destino: String?
    let eta: Date
    let secondsUntil: Int
    let delay: DelayStatus

    var id: String { "\(lineName)-\(Int(eta.timeIntervalSince1970))-\(destino ?? "")" }
}

// Línea de colectivo del catálogo (colectivos-lineas.json).
// No hay color oficial: se deriva uno determinístico del shortName.
struct BusLine: Identifiable, Hashable {
    let routeId: String
    let shortName: String
    let longName: String

    var id: String { routeId }
    var color: Color { BusLine.color(for: shortName) }

    // Paleta propia. 12 tonos legibles en fondo claro y oscuro.
    private static let palette: [String] = [
        "#E4572E", "#F3A712", "#2E9E5B", "#1E7FD4", "#7B4FB5", "#D6336C",
        "#0FA3A3", "#B5651D", "#5B7A2E", "#3D5AA9", "#C2417B", "#557A95"
    ]

    // Hash determinístico (djb2) del shortName -> índice de paleta.
    static func color(for shortName: String) -> Color {
        var hash = 5381
        for scalar in shortName.unicodeScalars {
            hash = (hash &* 33) &+ Int(scalar.value)
        }
        let idx = ((hash % palette.count) + palette.count) % palette.count
        return Color(hex: palette[idx])
    }
}
