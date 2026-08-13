import SwiftUI
import CoreLocation
import UIKit

// Vista "EcoBici cercanas". Lista las estaciones de BAClient ordenadas por
// distancia a la ubicación del usuario (LocationManager existente), con
// disponibilidad de bicis mecánicas/eléctricas y anclajes libres.
// Sin NavigationStack propio: la monta el contenedor que ya trae uno.
struct EcobiciNearbyView: View {
    @State private var locationManager = LocationManager.shared
    @State private var viewModel = EcobiciViewModel()

    var body: some View {
        content
            .background(Palette.background)
            .navigationTitle("EcoBici")
            .task {
                locationManager.startUpdatingLocation() // no-op si falta permiso
                await viewModel.load()
            }
            .task {
                await viewModel.autoRefreshLoop()
            }
    }

    @ViewBuilder
    private var content: some View {
        if !BASecrets.isConfigured {
            EmptyStateView(
                icon: "bicycle",
                title: "EcoBici no disponible",
                message: "Faltan las credenciales de la API de Transporte BA para mostrar estaciones."
            )
        } else if viewModel.isLoading && viewModel.stations.isEmpty {
            LoadingStateView(message: "Buscando estaciones de EcoBici…")
        } else if let loadError = viewModel.loadError, viewModel.stations.isEmpty {
            ErrorStateView(message: loadError) {
                Task { await viewModel.load() }
            }
        } else if viewModel.stations.isEmpty {
            EmptyStateView(
                icon: "bicycle",
                title: "Sin estaciones",
                message: "No encontramos estaciones de EcoBici ahora."
            )
        } else {
            stationList
        }
    }

    // (estación, distancia). Con ubicación: ordenadas por cercanía.
    // Sin ubicación: orden alfabético, para que la lista siga siendo usable.
    private var sortedStations: [(station: EcobiciStation, distance: CLLocationDistance?)] {
        guard let coordinate = locationManager.coordinate else {
            return viewModel.stations
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                .map { ($0, nil) }
        }
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return viewModel.stations
            .map { station in
                (station, CLLocation(latitude: station.lat, longitude: station.lng).distance(from: origin))
            }
            .sorted { ($0.1 ?? .greatestFiniteMagnitude) < ($1.1 ?? .greatestFiniteMagnitude) }
    }

    private var showsLocationBanner: Bool {
        switch locationManager.authorizationStatus {
        case .notDetermined, .denied, .restricted: return true
        default: return false
        }
    }

    private var stationList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if showsLocationBanner {
                    LocationCTABanner(status: locationManager.authorizationStatus) {
                        handleLocationCTA()
                    }
                }

                if let lastUpdated = viewModel.lastUpdated {
                    Text("Actualizado \(Formatting.clock(lastUpdated)) hs")
                        .font(.anden(11, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                ForEach(sortedStations, id: \.station.id) { pair in
                    EcobiciStationRow(station: pair.station, distance: pair.distance)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .refreshable {
            await viewModel.load()
        }
    }

    private func handleLocationCTA() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestPermission()
        default:
            openSettings()
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// Carga y refresco automático de estaciones EcoBici.
@MainActor
@Observable
final class EcobiciViewModel {
    private(set) var stations: [EcobiciStation] = []
    private(set) var isLoading = false
    private(set) var loadError: String?
    private(set) var lastUpdated: Date?

    func load() async {
        guard BASecrets.isConfigured else { return }
        if stations.isEmpty { isLoading = true }
        do {
            stations = try await BAClient.shared.ecobiciStations()
            loadError = nil
            lastUpdated = Date()
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    // Refresco cada 30s mientras la vista esté en pantalla. Se cancela solo
    // cuando SwiftUI cancela la Task del `.task` (la vista desaparece).
    func autoRefreshLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            await load()
        }
    }
}

// MARK: - Fila de estación

private struct EcobiciStationRow: View {
    let station: EcobiciStation
    var distance: CLLocationDistance?

    private var isInService: Bool { station.status == "IN_SERVICE" }

    private var availabilityColor: Color {
        guard isInService else { return Palette.noData }
        if station.bikesTotal == 0 { return Palette.majorDelay }
        if station.bikesTotal <= 2 { return Palette.minorDelay }
        return Palette.onTime
    }

    private var capacityFraction: CGFloat {
        guard isInService, station.capacity > 0 else { return 0 }
        return min(1, CGFloat(station.bikesTotal) / CGFloat(station.capacity))
    }

    var body: some View {
        HStack(spacing: 12) {
            ring

            VStack(alignment: .leading, spacing: 5) {
                Text(station.displayName)
                    .font(.anden(16, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let distance {
                        Text(Formatting.distanceText(meters: distance))
                        Text("·")
                    }
                    Text("\(station.docksAvailable) \(station.docksAvailable == 1 ? "anclaje libre" : "anclajes libres")")
                }
                .font(.anden(12, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)

                if isInService {
                    HStack(spacing: 8) {
                        BikeTypeChip(icon: "bicycle", count: station.bikesMechanical, color: Palette.onTime)
                        BikeTypeChip(icon: "bolt.fill", count: station.bikesEbike, color: Color(hex: "#3B82F6"))
                    }
                } else {
                    Text("Fuera de servicio")
                        .font(.anden(11, weight: .bold))
                        .foregroundStyle(Palette.noData)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(station.bikesTotal)")
                    .font(.andenCountdown(26))
                    .foregroundStyle(availabilityColor)
                Text(station.bikesTotal == 1 ? "bici" : "bicis")
                    .font(.anden(11, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.surface)
        )
        .accessibilityElement(children: .combine)
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(availabilityColor.opacity(0.25), lineWidth: 3)
            Circle()
                .trim(from: 0, to: capacityFraction)
                .stroke(availabilityColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "bicycle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(availabilityColor)
        }
        .frame(width: 38, height: 38)
    }
}

// Chip compacto de conteo por tipo de bici (mecánica / eléctrica), mismo
// lenguaje visual que DelayPill (cápsula con fill + stroke tenues).
private struct BikeTypeChip: View {
    let icon: String
    let count: Int
    let color: Color

    private var active: Bool { count > 0 }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text("\(count)")
                .font(.anden(11, weight: .bold))
        }
        .foregroundStyle(active ? color : Palette.textSecondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous).fill((active ? color : Palette.textSecondary).opacity(0.14))
        )
        .overlay(
            Capsule(style: .continuous).strokeBorder((active ? color : Palette.textSecondary).opacity(0.25), lineWidth: 0.5)
        )
    }
}

// MARK: - Banner de ubicación

private struct LocationCTABanner: View {
    let status: CLAuthorizationStatus
    let action: () -> Void

    private var title: String {
        status == .notDetermined ? "Activá tu ubicación" : "Ubicación desactivada"
    }

    private var message: String {
        status == .notDetermined
            ? "Activala para ordenar las estaciones por cercanía."
            : "Activá el permiso en Ajustes para ordenar por cercanía."
    }

    private var actionTitle: String {
        status == .notDetermined ? "Activar" : "Ajustes"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.circle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Palette.brand)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.anden(13, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                Text(message)
                    .font(.anden(12))
                    .foregroundStyle(Palette.textSecondary)
            }

            Spacer(minLength: 8)

            Button(action: action) {
                Text(actionTitle)
                    .font(.anden(12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Palette.brand))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.elevated)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            LazyVStack(spacing: 12) {
                LocationCTABanner(status: .notDetermined, action: {})
                EcobiciStationRow(
                    station: .preview(bikesMechanical: 4, bikesEbike: 2, docks: 8, status: "IN_SERVICE"),
                    distance: 320
                )
                EcobiciStationRow(
                    station: .preview(bikesMechanical: 1, bikesEbike: 0, docks: 12, status: "IN_SERVICE"),
                    distance: 850
                )
                EcobiciStationRow(
                    station: .preview(bikesMechanical: 0, bikesEbike: 0, docks: 0, status: "IN_SERVICE"),
                    distance: 1200
                )
                EcobiciStationRow(
                    station: .preview(bikesMechanical: 0, bikesEbike: 0, docks: 0, status: "STATION_OUT_OF_SERVICE"),
                    distance: nil
                )
            }
            .padding()
        }
        .background(Palette.background)
        .navigationTitle("EcoBici")
    }
}

private extension EcobiciStation {
    static func preview(bikesMechanical: Int, bikesEbike: Int, docks: Int, status: String) -> EcobiciStation {
        EcobiciStation(
            id: "2",
            name: "002 - Retiro I",
            lat: -34.5924,
            lng: -58.3747,
            capacity: bikesMechanical + bikesEbike + docks,
            bikesMechanical: bikesMechanical,
            bikesEbike: bikesEbike,
            bikesTotal: bikesMechanical + bikesEbike,
            docksAvailable: docks,
            status: status,
            lastReported: Date()
        )
    }
}
