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

// MARK: - OneBusAway (cuandosubo) — arribos de colectivo en vivo

// Referencia Hashable a una parada OBA, para navegar al tablero.
// Guarda lat/lng (no CLLocationCoordinate2D) para ser Hashable.
struct ObaStopRef: Hashable {
    let stopId: String
    let name: String
    let lat: Double
    let lng: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

// Una línea de colectivo cercana con su próximo arribo, resuelta contra una parada.
// (routeShortName + tripHeadsign) agrupados, el próximo arribo futuro.
struct BusLineNearby: Identifiable {
    let lineShort: String
    let headsign: String
    let eta: Date?
    let secondsUntil: Int
    let isLive: Bool
    var stopName: String
    let stopId: String
    let stopCoordinate: CLLocationCoordinate2D

    var id: String { "\(stopId)-\(lineShort)-\(headsign)" }

    var stopRef: ObaStopRef {
        ObaStopRef(stopId: stopId, name: stopName, lat: stopCoordinate.latitude, lng: stopCoordinate.longitude)
    }
}

// Un arribo de colectivo en una parada (tablero de parada OBA).
struct BusArrivalOba: Identifiable {
    let lineShort: String
    let headsign: String
    let eta: Date?
    let secondsUntil: Int
    let isLive: Bool
    // Posición GPS del coche que viene, SOLO cuando OBA la reporta en vivo
    // (tripStatus.predicted == true). nil si es una estimación por horario.
    let vehicleCoordinate: CLLocationCoordinate2D?
    // Viaje del coche, para pedir la traza del recorrido (shape).
    let tripId: String?

    var id: String { "\(lineShort)-\(headsign)-\(Int((eta ?? .distantPast).timeIntervalSince1970))" }
}

// Línea de colectivo del catálogo (colectivos-lineas.json).
// No hay color oficial: se deriva uno determinístico del shortName.
struct BusLine: Identifiable, Hashable {
    let routeId: String
    let shortName: String
    let longName: String

    var id: String { routeId }
    var color: Color { BusLine.color(for: shortName) }

    // Paleta propia. 24 tonos legibles en fondo claro y oscuro. No hay colores
    // oficiales por línea (OBA los devuelve vacíos), pero cada línea recibe uno
    // estable y bien distinto vía hash del número.
    private static let palette: [String] = [
        "#E4572E", "#F3A712", "#2E9E5B", "#1E7FD4", "#7B4FB5", "#D6336C",
        "#0FA3A3", "#B5651D", "#5B7A2E", "#3D5AA9", "#C2417B", "#557A95",
        "#E8590C", "#2F9E44", "#1971C2", "#9C36B5", "#C92A2A", "#0CA678",
        "#F08C00", "#4263EB", "#AE3EC9", "#087F5B", "#5C940D", "#A61E4D"
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
