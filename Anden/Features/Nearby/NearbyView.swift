import SwiftUI
import CoreLocation
import UIKit
import Observation

// Vista raíz "Cercanas". Prioriza la estación más próxima con su próximo arribo
// ya cargado, y lista el resto con distancia. Push al Buscador y al Tablero
// conviven en el mismo NavigationStack.
struct NearbyView: View {
    @State private var locationManager = LocationManager.shared
    @State private var viewModel = NearbyViewModel()
    @State private var path = NavigationPath()

    private enum NearbyRoute: Hashable {
        case search
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .background(Palette.background)
                .navigationTitle("Cercanas")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            path.append(NearbyRoute.search)
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .accessibilityLabel("Buscar estación")
                    }
                }
                .navigationDestination(for: NearbyRoute.self) { route in
                    switch route {
                    case .search:
                        SearchView()
                    }
                }
                .navigationDestination(for: Station.self) { station in
                    StationBoardView(station: station)
                }
        }
        .task {
            locationManager.startUpdatingLocation()
        }
        .task(id: nearbyStationIds) {
            guard !nearbyStations.isEmpty else { return }
            await viewModel.loadNextArrivals(for: nearbyStations)
        }
    }

    private var nearbyStations: [Station] {
        locationManager.nearest.map { $0.0 }
    }

    private var nearbyStationIds: [Int] {
        nearbyStations.map { $0.id }
    }

    private var distanceByStationId: [Int: CLLocationDistance] {
        Dictionary(uniqueKeysWithValues: locationManager.nearest.map { ($0.0.id, $0.1) })
    }

    @ViewBuilder
    private var content: some View {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            primingCard
        case .denied, .restricted:
            EmptyStateView(
                icon: "location.slash",
                title: "Ubicación desactivada",
                message: "Activá el permiso de ubicación en Ajustes para ver tus estaciones más cercanas.",
                actionTitle: "Abrir Ajustes"
            ) {
                openSettings()
            }
        case .authorizedWhenInUse, .authorizedAlways:
            authorizedContent
        @unknown default:
            EmptyStateView(
                icon: "location.slash",
                title: "Ubicación no disponible",
                message: "No pudimos determinar el estado del permiso de ubicación."
            )
        }
    }

    private var primingCard: some View {
        EmptyStateView(
            icon: "location.circle",
            title: "Activá tu ubicación",
            message: "Te mostramos automáticamente las estaciones de tren más cercanas y tu próximo arribo. Nunca compartimos tu ubicación.",
            actionTitle: "Activar ubicación"
        ) {
            locationManager.requestPermission()
        }
    }

    @ViewBuilder
    private var authorizedContent: some View {
        if locationManager.coordinate == nil {
            if let lastError = locationManager.lastError {
                ErrorStateView(message: lastError) {
                    locationManager.startUpdatingLocation()
                }
            } else {
                LoadingStateView(message: "Buscando tu ubicación…")
            }
        } else if nearbyStations.isEmpty {
            EmptyStateView(
                icon: "tram",
                title: "Sin estaciones cerca",
                message: "No encontramos estaciones con servicio cerca tuyo. Probá buscar por nombre.",
                actionTitle: "Buscar estación"
            ) {
                path.append(NearbyRoute.search)
            }
        } else {
            stationList
        }
    }

    private var stationList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if let first = nearbyStations.first, let distance = distanceByStationId[first.id] {
                    NavigationLink(value: first) {
                        NearbyHeroCard(
                            station: first,
                            distance: distance,
                            arrival: viewModel.arrivalsByStation[first.id],
                            isLoading: viewModel.loadingStations.contains(first.id)
                        )
                    }
                    .buttonStyle(.plain)
                }

                ForEach(nearbyStations.dropFirst()) { station in
                    NavigationLink(value: station) {
                        StationRowPreview(
                            station: station,
                            nextArrival: viewModel.arrivalsByStation[station.id],
                            distance: distanceByStationId[station.id]
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .refreshable {
            await viewModel.loadNextArrivals(for: nearbyStations)
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// Tarjeta destacada de la estación más cercana, con countdown grande.
private struct NearbyHeroCard: View {
    let station: Station
    let distance: CLLocationDistance
    let arrival: Arrival?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                LineBadge(line: station.line, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.nombre)
                        .font(.anden(20, weight: .bold))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                    Text(Formatting.distanceText(meters: distance))
                        .font(.anden(13))
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                LiveDot(active: arrival != nil)
            }

            if let arrival {
                HStack(alignment: .center, spacing: 14) {
                    CountdownText(secondsUntil: arrival.secondsUntil, big: true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("a \(arrival.destinationName)")
                            .font(.anden(15, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(1)
                        HStack(spacing: 8) {
                            DelayPill(arrival.delay)
                            if let track = arrival.trackName {
                                Text("Andén \(track)")
                                    .font(.anden(12))
                                    .foregroundStyle(Palette.textSecondary)
                            }
                        }
                    }
                    Spacer()
                }
            } else if isLoading {
                LoadingStateView(message: "Buscando tu próximo tren…")
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                EmptyStateView(
                    icon: "tram",
                    title: "Sin arribos",
                    message: "No hay próximos trenes informados para esta estación ahora."
                )
                .frame(maxWidth: .infinity, minHeight: 80)
            }
        }
        .andenCard()
    }
}

// Carga el próximo arribo de cada estación cercana con concurrencia limitada,
// para no disparar N requests simultáneas contra la API.
@MainActor
@Observable
final class NearbyViewModel {
    private(set) var arrivalsByStation: [Int: Arrival] = [:]
    private(set) var loadingStations: Set<Int> = []

    private let maxConcurrent = 3

    func loadNextArrivals(for stations: [Station]) async {
        guard !stations.isEmpty else { return }
        for station in stations { loadingStations.insert(station.id) }
        defer { for station in stations { loadingStations.remove(station.id) } }

        var index = 0
        await withTaskGroup(of: (Int, Arrival?).self) { group in
            func addNext() {
                guard index < stations.count else { return }
                let station = stations[index]
                index += 1
                group.addTask {
                    let arrivals = try? await SofseClient.shared.arrivals(stationId: station.id, limit: 1)
                    return (station.id, arrivals?.first)
                }
            }
            for _ in 0..<min(maxConcurrent, stations.count) { addNext() }
            while let (stationId, arrival) = await group.next() {
                arrivalsByStation[stationId] = arrival
                loadingStations.remove(stationId)
                addNext()
            }
        }
    }
}
