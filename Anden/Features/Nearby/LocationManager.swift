import CoreLocation
import Observation

// Envuelve CLLocationManager. Publica permiso, coordenada actual y estaciones
// cercanas (calculadas contra StationCatalog.shared). Actualizaciones livianas:
// precisión de ~100m y filtro de distancia de 50m, suficiente para ordenar estaciones.
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var coordinate: CLLocationCoordinate2D?
    private(set) var nearest: [(Station, CLLocationDistance)] = []
    private(set) var isUpdating = false
    private(set) var lastError: String?

    private let manager: CLLocationManager
    private let catalog: StationCatalog
    private let nearbyLimit: Int

    init(catalog: StationCatalog = .shared, nearbyLimit: Int = 8) {
        self.manager = CLLocationManager()
        self.catalog = catalog
        self.nearbyLimit = nearbyLimit
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50
    }

    // Dispara el diálogo de permiso del sistema. Solo tiene efecto si el estado es .notDetermined.
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    // Arranque liviano: no hace nada si todavía no hay permiso.
    func startUpdatingLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else { return }
        isUpdating = true
        manager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        isUpdating = false
        manager.stopUpdatingLocation()
    }

    private func recomputeNearest() {
        guard let coordinate else {
            nearest = []
            return
        }
        nearest = catalog.nearest(to: coordinate, limit: nearbyLimit)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            lastError = nil
            startUpdatingLocation()
        case .denied, .restricted:
            stopUpdatingLocation()
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        coordinate = location.coordinate
        lastError = nil
        recomputeNearest()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // No pisar una posición ya obtenida por un error transitorio puntual.
        guard coordinate == nil else { return }
        if let clError = error as? CLError, clError.code == .denied {
            return // ya lo cubre authorizationStatus
        }
        lastError = "No pudimos obtener tu ubicación."
    }
}
