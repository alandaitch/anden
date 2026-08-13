import Foundation
import MapKit
import CoreLocation

// Abre Apple Maps con indicaciones hacia una coordenada.
enum MapsOpener {

    // Indicaciones a pie.
    @MainActor
    static func walk(to coordinate: CLLocationCoordinate2D, name: String) {
        open(to: coordinate, name: name, mode: MKLaunchOptionsDirectionsModeWalking)
    }

    // Indicaciones en transporte público.
    @MainActor
    static func transit(to coordinate: CLLocationCoordinate2D, name: String) {
        open(to: coordinate, name: name, mode: MKLaunchOptionsDirectionsModeTransit)
    }

    @MainActor
    private static func open(to coordinate: CLLocationCoordinate2D, name: String, mode: String) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: mode])
    }
}
