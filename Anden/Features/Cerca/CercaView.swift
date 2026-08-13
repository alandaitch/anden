import SwiftUI
import CoreLocation
import UIKit
import Observation

// "Cerca" unificada multimodal. UN NavigationStack, chips de filtro arriba y UNA
// lista mezclada de lo más cercano a la ubicación, ordenada por distancia,
// combinando tren, subte, EcoBici y colectivos. Cada fila navega a su tablero
// y trae un botón "Ir" que abre Apple Maps con caminata a la parada/estación.
struct CercaView: View {
    @State private var locationManager = LocationManager.shared
    @State private var viewModel = CercaViewModel()
    @AppStorage("cercaFilter") private var storedFilter: String = CercaFilter.todos.rawValue

    @State private var path = NavigationPath()
    @State private var showComoLlego = false

    private var filter: CercaFilter {
        CercaFilter(rawValue: storedFilter) ?? .todos
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                filterChips
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 8)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Palette.background)
            .navigationTitle("Cerca")
            .navigationDestination(for: Station.self) { station in
                StationBoardView(station: station)
            }
            .navigationDestination(for: SubteStationRef.self) { ref in
                SubteStationBoardView(stationName: ref.stationName, line: ref.line)
            }
            .navigationDestination(for: BusStop.self) { stop in
                ColectivoStopBoardView(stop: stop)
            }
            .navigationDestination(for: EcobiciStation.self) { station in
                EcobiciStopDetailView(station: station)
            }
            .task {
                locationManager.startUpdatingLocation()
            }
            .task(id: coordinateKey) {
                await viewModel.load(coordinate: locationManager.coordinate)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showComoLlego = true
                    } label: {
                        Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                    }
                    .accessibilityLabel("Cómo llego")
                }
            }
            .sheet(isPresented: $showComoLlego) {
                ComoLlegoView()
            }
        }
    }

    // Clave estable para relanzar la carga cuando la ubicación cambia de verdad.
    private var coordinateKey: String {
        guard let c = locationManager.coordinate else { return "none" }
        return "\(Int(c.latitude * 1000))-\(Int(c.longitude * 1000))"
    }

    // MARK: - Chips de filtro

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CercaFilter.allCases) { f in
                    filterChip(f)
                }
            }
        }
    }

    private func filterChip(_ f: CercaFilter) -> some View {
        let selected = f == filter
        return Button {
            storedFilter = f.rawValue
        } label: {
            HStack(spacing: 6) {
                Image(systemName: f.icon)
                    .font(.system(size: 12, weight: .bold))
                Text(f.title)
                    .font(.anden(13, weight: .bold))
            }
            .foregroundStyle(selected ? .white : Palette.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(selected ? Palette.brand : Palette.surface)
            )
            .overlay(
                Capsule().strokeBorder(Palette.textSecondary.opacity(selected ? 0 : 0.18), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(f.title)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    // MARK: - Contenido

    @ViewBuilder
    private var content: some View {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            primingCard
        case .denied, .restricted:
            EmptyStateView(
                icon: "location.slash",
                title: "Ubicación desactivada",
                message: "Activá el permiso de ubicación en Ajustes para ver el transporte más cercano.",
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
            message: "Te mostramos trenes, subtes, EcoBici y colectivos cerca tuyo, ordenados por distancia. Nunca compartimos tu ubicación.",
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
        } else if viewModel.isLoading && viewModel.items.isEmpty {
            LoadingStateView(message: "Buscando transporte cerca tuyo…")
        } else {
            let items = viewModel.filteredItems(filter)
            if items.isEmpty {
                EmptyStateView(
                    icon: "mappin.slash",
                    title: "Nada cerca",
                    message: emptyMessage
                )
            } else {
                list(items)
            }
        }
    }

    private var emptyMessage: String {
        switch filter {
        case .todos:  return "No encontramos transporte cerca tuyo ahora."
        case .tren:   return "No hay estaciones de tren con servicio cerca tuyo."
        case .subte:  return "No hay estaciones de subte cerca tuyo."
        case .bici:   return "No hay estaciones de EcoBici cerca tuyo."
        case .bondi:  return "No hay paradas de colectivo cerca tuyo."
        }
    }

    private func list(_ items: [NearbyItem]) -> some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(items) { item in
                    NearbyItemRow(item: item) {
                        MapsOpener.walk(to: item.coordinate, name: item.name)
                    }
                    .onTapGesture {
                        path.append(item.route)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .refreshable {
            await viewModel.load(coordinate: locationManager.coordinate)
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// Aplica la ruta al NavigationPath. CercaRoute empaqueta el destino de cada modo.
private extension NavigationPath {
    mutating func append(_ route: CercaRoute) {
        switch route {
        case .train(let station):   append(station)
        case .subte(let ref):       append(ref)
        case .bici(let station):    append(station)
        case .bondi(let stop):      append(stop)
        }
    }
}

// MARK: - Filtro

enum CercaFilter: String, CaseIterable, Identifiable {
    case todos
    case tren
    case subte
    case bici
    case bondi

    var id: String { rawValue }

    var title: String {
        switch self {
        case .todos: return "Todos"
        case .tren:  return "Tren"
        case .subte: return "Subte"
        case .bici:  return "Bici"
        case .bondi: return "Bondi"
        }
    }

    var icon: String {
        switch self {
        case .todos: return "square.grid.2x2.fill"
        case .tren:  return "tram.fill"
        case .subte: return "tram.tunnel.fill"
        case .bici:  return "bicycle"
        case .bondi: return "bus.fill"
        }
    }
}

// MARK: - Modelo de fila mezclada

enum TransitMode {
    case tren
    case subte
    case bici
    case bondi

    var icon: String {
        switch self {
        case .tren:  return "tram.fill"
        case .subte: return "tram.tunnel.fill"
        case .bici:  return "bicycle"
        case .bondi: return "bus.fill"
        }
    }

    var label: String {
        switch self {
        case .tren:  return "Tren"
        case .subte: return "Subte"
        case .bici:  return "EcoBici"
        case .bondi: return "Colectivo"
        }
    }
}

// Destino de navegación de una fila, uno por modo.
enum CercaRoute: Hashable {
    case train(Station)
    case subte(SubteStationRef)
    case bici(EcobiciStation)
    case bondi(BusStop)
}

// Una fila de la lista mezclada, ya resuelta con su mini-dato y su color de modo.
struct NearbyItem: Identifiable {
    let id: String
    let mode: TransitMode
    let name: String
    let distance: CLLocationDistance
    let coordinate: CLLocationCoordinate2D
    let accentColor: Color
    let badgeText: String        // sigla/letra/inicial dentro del badge
    let subtitle: String?        // mini-dato del próximo (o disponibilidad)
    let subtitleColor: Color
    let route: CercaRoute
}

// MARK: - Fila

struct NearbyItemRow: View {
    let item: NearbyItem
    let onGo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            badge

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.anden(16, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(item.mode.label)
                        .font(.anden(11, weight: .bold))
                        .foregroundStyle(item.accentColor)
                    Text("·")
                        .foregroundStyle(Palette.textSecondary)
                    Text(Formatting.distanceText(meters: item.distance))
                        .font(.anden(12, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                }
                .lineLimit(1)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.anden(12, weight: .semibold))
                        .foregroundStyle(item.subtitleColor)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Button(action: onGo) {
                VStack(spacing: 3) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 15, weight: .bold))
                    Text("Ir")
                        .font(.anden(11, weight: .bold))
                }
                .foregroundStyle(Palette.brand)
                .frame(width: 46, height: 46)
                .background(Circle().fill(Palette.brand.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ir a \(item.name)")

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.textSecondary.opacity(0.5))
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.surface))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(item.accentColor)
                .frame(width: 4)
                .padding(.vertical, 12)
                .padding(.leading, 2)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var badge: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(item.accentColor)
            .frame(width: 40, height: 40)
            .overlay(
                Group {
                    if item.badgeText.isEmpty {
                        Image(systemName: item.mode.icon)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Text(item.badgeText)
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .padding(.horizontal, 2)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            )
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class CercaViewModel {
    private(set) var items: [NearbyItem] = []
    private(set) var isLoading = false

    // Cantidades por modo cuando se muestran mezclados.
    private let trainLimit = 5
    private let subteLimit = 5
    private let biciLimit = 5
    private let bondiLimit = 12   // paradas cargadas (el modo Bondi las muestra todas)
    private let bondiCapTodos = 6 // tope de colectivos en "Todos" para no inundar

    func filteredItems(_ filter: CercaFilter) -> [NearbyItem] {
        switch filter {
        case .todos:
            // En "Todos", limitamos los colectivos a los 6 más cercanos.
            var bondiSeen = 0
            return items.filter { item in
                guard item.mode == .bondi else { return true }
                bondiSeen += 1
                return bondiSeen <= bondiCapTodos
            }
        case .tren:  return items.filter { $0.mode == .tren }
        case .subte: return items.filter { $0.mode == .subte }
        case .bici:  return items.filter { $0.mode == .bici }
        case .bondi: return items.filter { $0.mode == .bondi }
        }
    }

    func load(coordinate: CLLocationCoordinate2D?) async {
        guard let coordinate else { return }
        isLoading = items.isEmpty
        defer { isLoading = false }

        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        // 1. Bases sincrónicas desde los catálogos embebidos.
        let trainPairs = StationCatalog.shared.nearest(to: coordinate, limit: trainLimit)
        let subtePairs = SubteCatalog.shared.nearest(to: coordinate, limit: subteLimit)
        let bondiPairs = ColectivoCatalog.shared.nearbyStops(to: coordinate, limit: bondiLimit)

        // 2. EcoBici: red. Trae disponibilidad de una sola llamada.
        var biciPairs: [(EcobiciStation, CLLocationDistance)] = []
        if BASecrets.isConfigured, let all = try? await BAClient.shared.ecobiciStations() {
            biciPairs = all
                .map { ($0, CLLocation(latitude: $0.lat, longitude: $0.lng).distance(from: origin)) }
                .sorted { $0.1 < $1.1 }
                .prefix(biciLimit)
                .map { $0 }
        }

        // 3. Filas base (sin mini-dato de arribo todavía).
        var result: [NearbyItem] = []
        result.append(contentsOf: trainPairs.map { pair in trainItem(pair.0, distance: pair.1) })
        result.append(contentsOf: subtePairs.map { pair in subteItem(pair.0, distance: pair.1, subtitle: nil, color: Palette.textSecondary) })
        result.append(contentsOf: biciPairs.map { pair in biciItem(pair.0, distance: pair.1) })
        result.append(contentsOf: bondiPairs.map { pair in bondiItem(pair.0, distance: pair.1) })
        result.sort { $0.distance < $1.distance }
        items = result

        // 4. Enriquecer con el próximo arribo (barato): tren y subte.
        await enrichTrains(trainPairs)
        await enrichSubtes(subtePairs)
    }

    // MARK: - Constructores de fila

    private func trainItem(_ station: Station, distance: CLLocationDistance, subtitle: String? = nil, color: Color = Palette.textSecondary) -> NearbyItem {
        NearbyItem(
            id: "tren-\(station.id)",
            mode: .tren,
            name: station.nombre,
            distance: distance,
            coordinate: station.coordinate,
            accentColor: station.line.color,
            badgeText: station.line.shortCode,
            subtitle: subtitle,
            subtitleColor: color,
            route: .train(station)
        )
    }

    private func subteItem(_ station: SubteStation, distance: CLLocationDistance, subtitle: String?, color: Color) -> NearbyItem {
        NearbyItem(
            id: "subte-\(station.id)",
            mode: .subte,
            name: station.name,
            distance: distance,
            coordinate: station.coordinate,
            accentColor: station.line.color,
            badgeText: station.line.letra,
            subtitle: subtitle,
            subtitleColor: color,
            route: .subte(SubteStationRef(routeId: station.line.routeId, stationName: station.name))
        )
    }

    private func biciItem(_ station: EcobiciStation, distance: CLLocationDistance) -> NearbyItem {
        let inService = station.status == "IN_SERVICE"
        let subtitle: String
        let color: Color
        if !inService {
            subtitle = "Fuera de servicio"
            color = Palette.noData
        } else {
            subtitle = "\(station.bikesTotal) \(station.bikesTotal == 1 ? "bici" : "bicis") · \(station.docksAvailable) \(station.docksAvailable == 1 ? "anclaje" : "anclajes")"
            color = station.bikesTotal == 0 ? Palette.majorDelay : (station.bikesTotal <= 2 ? Palette.minorDelay : Palette.onTime)
        }
        return NearbyItem(
            id: "bici-\(station.id)",
            mode: .bici,
            name: station.displayName,
            distance: distance,
            coordinate: station.coordinate,
            accentColor: Color(hex: "#0FA3A3"),
            badgeText: "",
            subtitle: subtitle,
            subtitleColor: color,
            route: .bici(station)
        )
    }

    private func bondiItem(_ stop: BusStop, distance: CLLocationDistance) -> NearbyItem {
        NearbyItem(
            id: "bondi-\(stop.code)",
            mode: .bondi,
            name: stop.name,
            distance: distance,
            coordinate: stop.coordinate,
            accentColor: Palette.brand,
            badgeText: "",
            subtitle: nil,
            subtitleColor: Palette.textSecondary,
            route: .bondi(stop)
        )
    }

    // MARK: - Enriquecimiento

    // Próximo tren de cada estación cercana, con concurrencia limitada.
    private func enrichTrains(_ pairs: [(Station, CLLocationDistance)]) async {
        guard !pairs.isEmpty else { return }
        let stations = pairs.map { $0.0 }
        var index = 0
        let maxConcurrent = 3
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
                if let arrival { applyTrainArrival(stationId: stationId, arrival: arrival) }
                addNext()
            }
        }
    }

    private func applyTrainArrival(stationId: Int, arrival: Arrival) {
        guard let idx = items.firstIndex(where: { $0.mode == .tren && $0.route.trainStationId == stationId }) else { return }
        let subtitle = "\(Formatting.etaText(secondsUntil: arrival.secondsUntil)) · a \(arrival.destinationName)"
        items[idx] = items[idx].withSubtitle(subtitle, color: Palette.onTime)
    }

    // Próximo subte de cada estación cercana, con UNA sola llamada a subteTrips().
    private func enrichSubtes(_ pairs: [(SubteStation, CLLocationDistance)]) async {
        guard !pairs.isEmpty, BASecrets.isConfigured else { return }
        guard let trips = try? await BAClient.shared.subteTrips() else { return }
        let now = Date()
        for (station, _) in pairs {
            let target = StationCatalog.normalize(station.name)
            var best: (secs: Int, dest: String)?
            for trip in trips where trip.line.routeId == station.line.routeId {
                guard let stop = trip.stops.first(where: { StationCatalog.normalize($0.name) == target }) else { continue }
                let secs = Int(stop.eta.timeIntervalSince(now).rounded())
                guard secs >= 0 else { continue }
                if best == nil || secs < best!.secs {
                    best = (secs, trip.stops.last?.name ?? "")
                }
            }
            guard let best else { continue }
            guard let idx = items.firstIndex(where: { $0.id == "subte-\(station.id)" }) else { continue }
            let dest = best.dest.isEmpty ? "" : " · a \(best.dest)"
            let subtitle = "\(Formatting.etaText(secondsUntil: best.secs))\(dest)"
            items[idx] = items[idx].withSubtitle(subtitle, color: Palette.onTime)
        }
    }
}

// MARK: - Helpers de mutación

private extension NearbyItem {
    func withSubtitle(_ subtitle: String, color: Color) -> NearbyItem {
        NearbyItem(
            id: id, mode: mode, name: name, distance: distance, coordinate: coordinate,
            accentColor: accentColor, badgeText: badgeText,
            subtitle: subtitle, subtitleColor: color, route: route
        )
    }
}

private extension CercaRoute {
    var trainStationId: Int? {
        if case .train(let station) = self { return station.id }
        return nil
    }
}

// MARK: - Detalle simple de estación EcoBici

// Vista de detalle de una estación EcoBici. La API no da arribos; muestra
// disponibilidad y ofrece "Ir" (caminata) y "Cómo llego" (transporte) a Maps.
struct EcobiciStopDetailView: View {
    let station: EcobiciStation

    private var inService: Bool { station.status == "IN_SERVICE" }

    private var availabilityColor: Color {
        guard inService else { return Palette.noData }
        if station.bikesTotal == 0 { return Palette.majorDelay }
        if station.bikesTotal <= 2 { return Palette.minorDelay }
        return Palette.onTime
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                availabilityCard
                actionButtons
                Text("EcoBici no informa un horario de arribo. Te mostramos la disponibilidad en vivo de la estación.")
                    .font(.anden(12, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("EcoBici")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "#0FA3A3"))
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: "bicycle")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(station.displayName)
                    .font(.anden(22, weight: .heavy))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(inService ? "En servicio" : "Fuera de servicio")
                    .font(.anden(13, weight: .semibold))
                    .foregroundStyle(inService ? Palette.onTime : Palette.noData)
            }
            Spacer(minLength: 0)
        }
    }

    private var availabilityCard: some View {
        HStack(spacing: 20) {
            metric(value: "\(station.bikesMechanical)", label: "mecánicas", icon: "bicycle", color: Palette.onTime)
            metric(value: "\(station.bikesEbike)", label: "eléctricas", icon: "bolt.fill", color: Color(hex: "#3B82F6"))
            metric(value: "\(station.docksAvailable)", label: "anclajes", icon: "parkingsign", color: Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.surface))
        .overlay(alignment: .topTrailing) {
            Text("\(station.bikesTotal)")
                .font(.andenCountdown(22))
                .foregroundStyle(availabilityColor)
                .padding(12)
        }
    }

    private func metric(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(.anden(22, weight: .heavy))
                .foregroundStyle(Palette.textPrimary)
            Text(label)
                .font(.anden(11, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                MapsOpener.walk(to: station.coordinate, name: station.displayName)
            } label: {
                Label("Ir", systemImage: "figure.walk")
                    .font(.anden(14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(Palette.brand))
            }
            .buttonStyle(.plain)

            Button {
                MapsOpener.transit(to: station.coordinate, name: station.displayName)
            } label: {
                Label("Cómo llego", systemImage: "tram.fill")
                    .font(.anden(14, weight: .bold))
                    .foregroundStyle(Palette.brand)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(Palette.brand.opacity(0.14)))
            }
            .buttonStyle(.plain)
        }
    }
}
