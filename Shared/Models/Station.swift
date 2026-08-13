import Foundation
import CoreLocation

// Estación del catálogo embebido (estaciones.json).
struct Station: Identifiable, Codable, Hashable {
    let id: Int
    let nombre: String
    let lat: Double
    let lng: Double
    let linea: String?
    let ramales: [Int]
    let ramalesOperativos: [Int]
    let gerenciaId: Int?
    let visibleEnApp: Bool
    let enRamalPublico: Bool
    let tieneArribosHoy: Bool
    let distanciaObeliscoKm: Double
    let andenes: Int?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    var line: TrainLine {
        if let gerenciaId { return TrainLine.line(id: gerenciaId) }
        return TrainLine.line(nombre: linea)
    }
}
