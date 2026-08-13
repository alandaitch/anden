import Foundation
import CoreLocation

// Estación de EcoBici (GBFS). Une stationInformation + stationStatus.
struct EcobiciStation: Identifiable, Hashable {
    let id: String
    let name: String
    let lat: Double
    let lng: Double
    let capacity: Int
    let bikesMechanical: Int
    let bikesEbike: Int
    let bikesTotal: Int
    let docksAvailable: Int
    let status: String
    let lastReported: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    // Nombre sin el prefijo numérico. "002 - Retiro I" -> "Retiro I".
    var displayName: String {
        let parts = name.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count == 2,
           Int(parts[0].trimmingCharacters(in: .whitespaces)) != nil {
            return parts[1].trimmingCharacters(in: .whitespaces)
        }
        return name.trimmingCharacters(in: .whitespaces)
    }
}
