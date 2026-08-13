import Foundation
import MapKit
import Observation

// Envuelve MKLocalSearchCompleter. Publica sugerencias de autocompletado de
// lugares mientras el usuario escribe un destino, sesgadas a la región del
// AMBA. Resuelve la sugerencia elegida a su MKMapItem (coordenada + nombre)
// para abrir Apple Maps. No depende de la API de Transporte BA: usa
// directamente el motor de búsqueda de Apple.
@Observable
final class DestinationSearchModel: NSObject, MKLocalSearchCompleterDelegate {

    // Región de sesgo: Obelisco, radio amplio para cubrir CABA + conurbano
    // (Pilar, Ezeiza, La Plata aprox).
    static let ambaRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -34.6037, longitude: -58.3816),
        span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
    )

    private(set) var suggestions: [MKLocalSearchCompletion] = []
    private(set) var isSearching = false
    private(set) var searchError: String?
    private(set) var isResolving = false
    private(set) var resolveError: String?

    var query: String = "" {
        didSet {
            searchError = nil
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                suggestions = []
                isSearching = false
                completer.queryFragment = ""
            } else {
                isSearching = true
                completer.queryFragment = query
            }
        }
    }

    private let completer: MKLocalSearchCompleter

    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.resultTypes = [.address, .pointOfInterest]
        completer.region = Self.ambaRegion
        completer.delegate = self
    }

    // Reintento manual desde el estado de error: repite la búsqueda actual.
    func retry() {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        searchError = nil
        isSearching = true
        completer.queryFragment = query
    }

    // MARK: - MKLocalSearchCompleterDelegate

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results
        searchError = nil
        isSearching = false
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
        isSearching = false
        searchError = Self.message(for: error)
    }

    // MARK: - Resolución

    // Resuelve una sugerencia elegida a su lugar real (coordenada + nombre).
    @MainActor
    func resolve(_ completion: MKLocalSearchCompletion) async -> MKMapItem? {
        isResolving = true
        resolveError = nil
        defer { isResolving = false }

        let request = MKLocalSearch.Request(completion: completion)
        request.region = Self.ambaRegion
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else {
                resolveError = "No encontramos ese destino."
                return nil
            }
            return item
        } catch {
            resolveError = Self.message(for: error)
            return nil
        }
    }

    func clearResolveError() {
        resolveError = nil
    }

    // MARK: - Mensajes

    // Distingue una caída del servicio de búsqueda (server-side) de un error
    // transitorio de red, con mensaje es-AR propio para cada caso.
    private static func message(for error: Error) -> String {
        if let mkError = error as? MKError {
            switch mkError.code {
            case .serverFailure, .loadingThrottled, .decodingFailed:
                return "Búsqueda de lugares no disponible en este momento."
            default:
                break
            }
        }
        return "No pudimos buscar destinos. Revisá tu conexión."
    }
}
