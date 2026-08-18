import SwiftUI
import MapKit
import CoreLocation

// Mapa multimodal en vivo con capas seleccionables.
// Un solo Map(iOS 17). Cuatro capas independientes:
//   Trenes      -> posiciones GPS en vivo + pines de estaciones cercanas.
//   Subte       -> pines de estaciones del catálogo (sin GPS).
//   Bici        -> estaciones EcoBici, color por disponibilidad.
//   Colectivos  -> puntos GPS en vivo cerca del centro, color por línea.
// Cada capa tiene su propio ciclo de carga y refresco. Las capas activas
// se persisten en @AppStorage.
struct NetworkMapView: View {
    @AppStorage("mapaCapasActivas") private var storedLayers = "trenes,subte"

    @State private var model = NetworkMapModel()
    @State private var camera: MapCameraPosition = .region(NetworkMapModel.ambaRegion)
    @State private var currentRegion = NetworkMapModel.ambaRegion
    @State private var path: [MapRoute] = []
    @State private var selectedArrival: Arrival?
    @State private var selectedBike: EcobiciStation?
    @State private var selectedBus: BusPosition?
    @State private var showSearch = false

    // Límites de zoom del control flotante.
    private static let minSpan: Double = 0.002
    private static let maxSpan: Double = 1.5

    @State private var locationManager = LocationManager.shared

    // Capas activas derivadas del string persistido.
    private var active: Set<MapLayer> {
        Set(storedLayers.split(separator: ",").compactMap { MapLayer(rawValue: String($0)) })
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .top) {
                mapLayer

                VStack(spacing: 0) {
                    layerBar
                    Spacer()
                    legend
                }
            }
            .overlay(alignment: .bottomTrailing) {
                zoomControl
                    .padding(.trailing, 16)
                    .padding(.bottom, 116)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("Red en vivo")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: MapRoute.self) { route in
                switch route {
                case .trainStation(let station):
                    StationBoardView(station: station)
                case .subteStation(let ref):
                    SubteStationBoardView(stationName: ref.stationName, line: ref.line)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        centerOnUser()
                    } label: {
                        Image(systemName: "location")
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                StationSearchSheet { station in
                    showSearch = false
                    focus(on: station.coordinate)
                }
            }
            .sheet(item: $selectedArrival) { arrival in
                NavigationStack {
                    ServiceDetailView(arrival: arrival)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Listo") { selectedArrival = nil }
                            }
                        }
                }
            }
            .sheet(item: $selectedBike) { station in
                BikeStopSheet(station: station) { selectedBike = nil }
                    .presentationDetents([.height(280)])
            }
            .sheet(item: $selectedBus) { bus in
                BusInfoSheet(bus: bus) { selectedBus = nil }
                    .presentationDetents([.height(240)])
            }
            .onAppear {
                locationManager.startUpdatingLocation()
                model.apply(active: active)
            }
            .onChange(of: storedLayers) { _, _ in
                model.apply(active: active)
            }
            .onDisappear {
                model.stopAll()
            }
        }
    }

    // MARK: - Mapa

    private var mapLayer: some View {
        Map(position: $camera) {
            UserAnnotation()

            if active.contains(.trenes) {
                ForEach(model.trainStations) { station in
                    Annotation("", coordinate: station.coordinate, anchor: .center) {
                        StationDot(color: station.line.color) {
                            path.append(.trainStation(station))
                        }
                    }
                    .annotationTitles(.hidden)
                }
                ForEach(model.trains) { train in
                    if let coord = train.trainLocation {
                        Annotation("", coordinate: coord, anchor: .center) {
                            VehicleMarker(icon: "tram.fill", color: train.line.color) {
                                selectedArrival = train
                            }
                        }
                        .annotationTitles(.hidden)
                    }
                }
            }

            if active.contains(.subte) {
                ForEach(model.subtes) { station in
                    Annotation("", coordinate: station.coordinate, anchor: .center) {
                        SubteDot(line: station.line) {
                            path.append(.subteStation(SubteStationRef(
                                routeId: station.line.routeId,
                                stationName: station.name
                            )))
                        }
                    }
                    .annotationTitles(.hidden)
                }
            }

            if active.contains(.bici) {
                EcobiciMapLayer.annotations(stations: model.bikes) { selectedBike = $0 }
            }

            if active.contains(.colectivos) {
                ForEach(model.buses) { bus in
                    Annotation("", coordinate: bus.coordinate, anchor: .center) {
                        BusDot(color: model.busColor(for: bus)) {
                            selectedBus = bus
                        }
                    }
                    .annotationTitles(.hidden)
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .ignoresSafeArea(edges: .bottom)
        .onMapCameraChange(frequency: .continuous) { context in
            currentRegion = context.region
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            model.setCenter(context.region.center, active: active)
        }
    }

    // MARK: - Control de zoom flotante

    private var zoomControl: some View {
        VStack(spacing: 10) {
            ZoomButton(system: "plus") { zoom(by: 0.5) }
            ZoomButton(system: "minus") { zoom(by: 2.0) }
        }
    }

    // Zoom manteniendo el centro. factor < 1 acerca, factor > 1 aleja.
    private func zoom(by factor: Double) {
        let center = currentRegion.center
        let lat = min(Self.maxSpan, max(Self.minSpan, currentRegion.span.latitudeDelta * factor))
        let lng = min(Self.maxSpan, max(Self.minSpan, currentRegion.span.longitudeDelta * factor))
        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: lat, longitudeDelta: lng)
        )
        currentRegion = region
        withAnimation(.easeInOut(duration: 0.25)) {
            camera = .region(region)
        }
    }

    // MARK: - Barra de capas

    private var layerBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                allChip
                ForEach(MapLayer.allCases) { layer in
                    LayerChip(
                        layer: layer,
                        isActive: active.contains(layer),
                        isLoading: model.isLoading(layer)
                    ) {
                        toggle(layer)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }

    private var allChip: some View {
        let allOn = active.count == MapLayer.allCases.count
        return Button {
            setAll(!allOn)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: allOn ? "circle.grid.2x2.fill" : "circle.grid.2x2")
                    .font(.system(size: 13, weight: .bold))
                Text("Todos")
                    .font(.anden(13, weight: .semibold))
            }
            .foregroundStyle(allOn ? .white : Palette.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(allOn ? Palette.brand : Palette.elevated, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Leyenda

    private var legend: some View {
        VStack(spacing: 8) {
            if !active.isEmpty {
                HStack(spacing: 12) {
                    ForEach(MapLayer.allCases.filter { active.contains($0) }) { layer in
                        LegendItem(layer: layer, count: model.count(layer))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(.ultraThinMaterial, in: Capsule())
            }

            HStack(spacing: 8) {
                if model.anyLoading(in: active) {
                    ProgressView().scaleEffect(0.7)
                }
                Text(statusText)
                    .font(.anden(12, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if model.hasLiveData(in: active) {
                    LiveDot(active: true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private var statusText: String {
        if active.isEmpty { return "Elegí una capa arriba." }
        if let failed = model.firstFailure(in: active) { return failed }
        if let updated = model.lastUpdated {
            return "Actualizado \(Formatting.clock(updated)) hs"
        }
        return "Cargando red…"
    }

    // MARK: - Acciones

    private func toggle(_ layer: MapLayer) {
        var set = active
        if set.contains(layer) { set.remove(layer) } else { set.insert(layer) }
        persist(set)
    }

    private func setAll(_ on: Bool) {
        persist(on ? Set(MapLayer.allCases) : [])
    }

    private func persist(_ set: Set<MapLayer>) {
        storedLayers = MapLayer.allCases.filter { set.contains($0) }.map(\.rawValue).joined(separator: ",")
    }

    private func centerOnUser() {
        guard let coord = locationManager.coordinate else {
            locationManager.requestPermission()
            return
        }
        focus(on: coord)
    }

    private func focus(on coordinate: CLLocationCoordinate2D) {
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
        currentRegion = region
        withAnimation(.easeInOut(duration: 0.4)) {
            camera = .region(region)
        }
        model.setCenter(coordinate, active: active)
    }
}

// MARK: - Capas

enum MapLayer: String, CaseIterable, Identifiable {
    case trenes, subte, bici, colectivos

    var id: String { rawValue }

    var label: String {
        switch self {
        case .trenes: return "Trenes"
        case .subte: return "Subte"
        case .bici: return "Bici"
        case .colectivos: return "Colectivos"
        }
    }

    var icon: String {
        switch self {
        case .trenes: return "tram.fill"
        case .subte: return "tram.tunnel.fill"
        case .bici: return "bicycle"
        case .colectivos: return "bus.fill"
        }
    }

    var tint: Color {
        switch self {
        case .trenes: return Color(hex: "#1E7FD4")
        case .subte: return Color(hex: "#00A650")
        case .bici: return Palette.onTime
        case .colectivos: return Color(hex: "#E4572E")
        }
    }
}

// Destino de navegación del mapa.
enum MapRoute: Hashable {
    case trainStation(Station)
    case subteStation(SubteStationRef)
}

// MARK: - Modelo de datos del mapa

@MainActor
@Observable
final class NetworkMapModel {
    static let ambaRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -34.62, longitude: -58.44),
        span: MKCoordinateSpan(latitudeDelta: 0.55, longitudeDelta: 0.55)
    )

    enum LayerState: Equatable {
        case idle
        case loading
        case ready
        case failed(String)
        case unavailable(String)
    }

    private(set) var trains: [Arrival] = []
    private(set) var trainStations: [Station] = []
    private(set) var subtes: [SubteStation] = []
    private(set) var bikes: [EcobiciStation] = []
    private(set) var buses: [BusPosition] = []

    private(set) var trainState: LayerState = .idle
    private(set) var subteState: LayerState = .idle
    private(set) var bikeState: LayerState = .idle
    private(set) var busState: LayerState = .idle

    private(set) var lastUpdated: Date?

    private var center = NetworkMapModel.ambaRegion.center
    private var tasks: [MapLayer: Task<Void, Never>] = [:]

    // MARK: Ciclo de vida de capas

    // Arranca las capas nuevas, apaga las que se desactivaron.
    func apply(active: Set<MapLayer>) {
        for layer in MapLayer.allCases {
            if active.contains(layer) {
                if tasks[layer] == nil { tasks[layer] = makeTask(for: layer) }
            } else if tasks[layer] != nil {
                tasks[layer]?.cancel()
                tasks[layer] = nil
                clear(layer)
            }
        }
    }

    func stopAll() {
        for (_, task) in tasks { task.cancel() }
        tasks.removeAll()
    }

    // Nuevo centro del mapa. Recalcula pines de estaciones de tren cercanas
    // (baratísimo) para que sigan al usuario. Los colectivos se re-piden en su tick.
    func setCenter(_ coordinate: CLLocationCoordinate2D, active: Set<MapLayer>) {
        center = coordinate
        if active.contains(.trenes) { recomputeTrainStations() }
    }

    private func clear(_ layer: MapLayer) {
        switch layer {
        case .trenes:
            trains = []; trainStations = []; trainState = .idle
        case .subte:
            subtes = []; subteState = .idle
        case .bici:
            bikes = []; bikeState = .idle
        case .colectivos:
            buses = []; busState = .idle
        }
    }

    private func makeTask(for layer: MapLayer) -> Task<Void, Never> {
        switch layer {
        case .trenes:      return Task { await self.runTrains() }
        case .subte:       return Task { await self.runSubte() }
        case .bici:        return Task { await self.runBikes() }
        case .colectivos:  return Task { await self.runBuses() }
        }
    }

    // MARK: Consultas de estado para la UI

    func isLoading(_ layer: MapLayer) -> Bool { state(layer) == .loading }

    func anyLoading(in active: Set<MapLayer>) -> Bool {
        active.contains { state($0) == .loading }
    }

    func hasLiveData(in active: Set<MapLayer>) -> Bool {
        (active.contains(.trenes) && !trains.isEmpty) ||
        (active.contains(.colectivos) && !buses.isEmpty)
    }

    func count(_ layer: MapLayer) -> Int {
        switch layer {
        case .trenes: return trains.count
        case .subte: return subtes.count
        case .bici: return bikes.count
        case .colectivos: return buses.count
        }
    }

    func firstFailure(in active: Set<MapLayer>) -> String? {
        for layer in MapLayer.allCases where active.contains(layer) {
            if case .failed(let m) = state(layer) { return m }
            if case .unavailable(let m) = state(layer) { return m }
        }
        return nil
    }

    private func state(_ layer: MapLayer) -> LayerState {
        switch layer {
        case .trenes: return trainState
        case .subte: return subteState
        case .bici: return bikeState
        case .colectivos: return busState
        }
    }

    // Color de un colectivo: por línea si matchea el catálogo, gris si no.
    func busColor(for bus: BusPosition) -> Color {
        if let routeId = bus.routeId, let line = ColectivoCatalog.shared.line(routeId: routeId) {
            return line.color
        }
        return Palette.noData
    }

    // MARK: Loops por capa

    // Trenes: GPS en vivo, refresco cada 25 s.
    private func runTrains() async {
        recomputeTrainStations()
        while !Task.isCancelled {
            if trains.isEmpty { trainState = .loading }
            let (result, hadError) = await gatherTrains()
            if Task.isCancelled { break }
            withAnimation(.linear(duration: 0.9)) {
                trains = result.sorted { $0.secondsUntil < $1.secondsUntil }
            }
            if !result.isEmpty {
                trainState = .ready
                lastUpdated = Date()
            } else if hadError {
                trainState = .failed("No pude cargar los trenes en vivo.")
            } else {
                trainState = .ready
            }
            try? await Task.sleep(nanoseconds: 25_000_000_000)
        }
    }

    // Subte: catálogo estático, sin GPS. Una sola carga.
    private func runSubte() async {
        subteState = .loading
        let stations = SubteCatalog.shared.all
        if Task.isCancelled { return }
        if stations.isEmpty {
            subteState = .unavailable("No pude cargar las estaciones de subte.")
        } else {
            subtes = stations
            subteState = .ready
        }
    }

    // Bici: EcoBici, refresco cada 30 s.
    private func runBikes() async {
        guard BASecrets.isConfigured else {
            bikeState = .unavailable("EcoBici no disponible: faltan credenciales de la API.")
            return
        }
        while !Task.isCancelled {
            if bikes.isEmpty { bikeState = .loading }
            do {
                let result = try await EcobiciMapLayer.fetchStations()
                if Task.isCancelled { break }
                bikes = result
                bikeState = result.isEmpty ? .failed("Sin estaciones de EcoBici ahora.") : .ready
                lastUpdated = Date()
            } catch {
                if Task.isCancelled { break }
                if bikes.isEmpty { bikeState = .failed("No pude cargar EcoBici.") }
            }
            try? await Task.sleep(nanoseconds: 30_000_000_000)
        }
    }

    // Colectivos: GPS en vivo cerca del centro, refresco cada 15 s.
    private func runBuses() async {
        guard BASecrets.isConfigured else {
            busState = .unavailable("Colectivos no disponibles: faltan credenciales de la API.")
            return
        }
        while !Task.isCancelled {
            if buses.isEmpty { busState = .loading }
            do {
                let result = try await BAClient.shared.colectivoPositions(near: center, maxCount: 350)
                if Task.isCancelled { break }
                buses = result
                busState = result.isEmpty ? .failed("Sin colectivos con GPS ahora.") : .ready
                lastUpdated = Date()
            } catch let error as APIError {
                if Task.isCancelled { break }
                if buses.isEmpty { busState = .failed(error.errorDescription ?? "No pude cargar los colectivos.") }
            } catch {
                if Task.isCancelled { break }
                if buses.isEmpty { busState = .failed("No pude cargar los colectivos.") }
            }
            try? await Task.sleep(nanoseconds: 15_000_000_000)
        }
    }

    // MARK: Helpers de trenes

    // Pines de estaciones de tren cercanas al centro (públicas). Barato, se llama en cada pan.
    private func recomputeTrainStations() {
        trainStations = StationCatalog.shared.nearest(to: center, limit: 28).map { $0.0 }
    }

    // Junta trenes con GPS muestreando estaciones de las líneas cubiertas.
    // Concurrencia acotada por chunks para no golpear la API de golpe. Dedup por serviceId.
    private func gatherTrains() async -> ([Arrival], Bool) {
        let covered = TrainLine.all.filter { $0.covered }
        var sample: [Station] = []
        for line in covered {
            let stations = StationCatalog.shared.all
                .filter { $0.gerenciaId == line.id && $0.enRamalPublico && $0.tieneArribosHoy }
                .sorted { $0.distanciaObeliscoKm < $1.distanciaObeliscoKm }
            sample.append(contentsOf: Self.spread(stations, count: 3))
        }
        var seen = Set<Int>()
        sample = sample.filter { seen.insert($0.id).inserted }

        var collected: [String: Arrival] = [:]
        var anyError = false

        for chunk in sample.chunked(into: 5) {
            if Task.isCancelled { break }
            await withTaskGroup(of: Result<[Arrival], Error>.self) { group in
                for station in chunk {
                    group.addTask {
                        do { return .success(try await SofseClient.shared.arrivals(stationId: station.id, limit: 6)) }
                        catch { return .failure(error) }
                    }
                }
                for await res in group {
                    switch res {
                    case .success(let list):
                        for arrival in list where arrival.trainLocation != nil {
                            let key = arrival.serviceId ?? arrival.id
                            if let existing = collected[key] {
                                if arrival.secondsUntil < existing.secondsUntil { collected[key] = arrival }
                            } else {
                                collected[key] = arrival
                            }
                        }
                    case .failure:
                        anyError = true
                    }
                }
            }
        }
        return (Array(collected.values), anyError)
    }

    // Toma N elementos repartidos a lo largo de la lista, no los primeros N.
    private static func spread(_ items: [Station], count: Int) -> [Station] {
        guard items.count > count else { return items }
        let step = Double(items.count) / Double(count)
        return (0..<count).map { items[Int(Double($0) * step)] }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Anotaciones

// Área tocable mínima para anotaciones chicas del mapa.
// Envuelve un contenido visual con un hit-area circular generoso y un tap
// que el Map no intercepta (a diferencia de Button dentro de Annotation).
private struct TappableAnnotation<Content: View>: View {
    var hitSize: CGFloat = 32
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(width: hitSize, height: hitSize)
            .contentShape(Circle())
            .onTapGesture(perform: action)
    }
}

// Marcador de vehículo (tren) con ícono. Tap abre el detalle.
private struct VehicleMarker: View {
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        TappableAnnotation(hitSize: 34, action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}

// Pin liviano de estación de tren. Tap abre su tablero.
private struct StationDot: View {
    let color: Color
    let action: () -> Void

    var body: some View {
        TappableAnnotation(hitSize: 30, action: action) {
            Circle()
                .fill(color.opacity(0.55))
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 1.5))
        }
    }
}

// Pin de estación de subte con la letra de la línea. Tap abre su tablero.
private struct SubteDot: View {
    let line: SubteLine
    let action: () -> Void

    var body: some View {
        TappableAnnotation(hitSize: 34, action: action) {
            ZStack {
                Circle()
                    .fill(line.color)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                Text(line.letra)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }
}

// Punto de colectivo. Tap abre un callout con línea/interno/patente.
// Son cientos: el visual queda chico, pero el hit-area es generoso.
private struct BusDot: View {
    let color: Color
    let action: () -> Void

    var body: some View {
        TappableAnnotation(hitSize: 28, action: action) {
            Circle()
                .fill(color)
                .frame(width: 11, height: 11)
                .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1))
        }
    }
}

// MARK: - Chips y leyenda

private struct LayerChip: View {
    let layer: MapLayer
    let isActive: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView().scaleEffect(0.6).frame(width: 14, height: 14)
                } else {
                    Image(systemName: layer.icon)
                        .font(.system(size: 12, weight: .bold))
                }
                Text(layer.label)
                    .font(.anden(13, weight: .semibold))
            }
            .foregroundStyle(isActive ? .white : Palette.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isActive ? layer.tint : Palette.elevated, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct LegendItem: View {
    let layer: MapLayer
    let count: Int

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(layer.tint)
                .frame(width: 9, height: 9)
            Text(count > 0 ? "\(layer.label) \(count)" : layer.label)
                .font(.anden(11, weight: .semibold))
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Botón de zoom flotante

private struct ZoomButton: View {
    let system: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
                .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hoja de detalle de colectivo

private struct BusInfoSheet: View {
    let bus: BusPosition
    let onClose: () -> Void

    // Número de línea. shortName del catálogo si matchea, si no "Línea s/d".
    private var lineTitle: String {
        if let rid = bus.routeId, let line = ColectivoCatalog.shared.line(routeId: rid) {
            return "Línea \(line.shortName)"
        }
        return "Línea s/d"
    }

    private var lineColor: Color {
        if let rid = bus.routeId, let line = ColectivoCatalog.shared.line(routeId: rid) {
            return line.color
        }
        return Palette.noData
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(lineColor)
                            .frame(width: 34, height: 34)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                        Image(systemName: "bus.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lineTitle)
                            .font(.anden(18, weight: .bold))
                            .foregroundStyle(Palette.textPrimary)
                        Text("Colectivo en vivo")
                            .font(.anden(12, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Spacer()
                }

                HStack(spacing: 10) {
                    BusInfoStat(value: bus.interno ?? "s/d", label: "interno")
                    BusInfoStat(value: bus.patente ?? "s/d", label: "patente")
                }

                Button {
                    MapsOpener.transit(to: bus.coordinate, name: lineTitle)
                } label: {
                    Label("Cómo llego", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.anden(15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Palette.brand))
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { onClose() }
                }
            }
        }
    }
}

private struct BusInfoStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.anden(20, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.anden(11, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.surface))
    }
}

// MARK: - Hoja de detalle de estación EcoBici

private struct BikeStopSheet: View {
    let station: EcobiciStation
    let onClose: () -> Void

    private var isInService: Bool { station.status == "IN_SERVICE" }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    EcobiciMapPin(station: station, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(station.displayName)
                            .font(.anden(18, weight: .bold))
                            .foregroundStyle(Palette.textPrimary)
                        Text(isInService ? "En servicio" : "Fuera de servicio")
                            .font(.anden(12, weight: .medium))
                            .foregroundStyle(isInService ? Palette.onTime : Palette.noData)
                    }
                    Spacer()
                }

                HStack(spacing: 10) {
                    BikeStat(value: station.bikesMechanical, label: "mecánicas", color: Palette.onTime)
                    BikeStat(value: station.bikesEbike, label: "eléctricas", color: Color(hex: "#3B82F6"))
                    BikeStat(value: station.docksAvailable, label: "anclajes", color: Palette.textSecondary)
                }

                Button {
                    MapsOpener.walk(to: station.coordinate, name: station.displayName)
                } label: {
                    Label("Ir a pie", systemImage: "figure.walk")
                        .font(.anden(15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Palette.brand))
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { onClose() }
                }
            }
        }
    }
}

private struct BikeStat: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.andenCountdown(24))
                .foregroundStyle(color)
            Text(label)
                .font(.anden(11, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.surface))
    }
}

// MARK: - Buscador de estación de tren

private struct StationSearchSheet: View {
    let onSelect: (Station) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [Station] {
        query.isEmpty ? [] : StationCatalog.shared.search(query)
    }

    var body: some View {
        NavigationStack {
            Group {
                if query.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "Buscá una estación",
                        message: "Escribí el nombre para centrar el mapa ahí."
                    )
                } else if results.isEmpty {
                    EmptyStateView(
                        icon: "questionmark.circle",
                        title: "Sin resultados",
                        message: "No encontré estaciones con ese nombre."
                    )
                } else {
                    List(results) { station in
                        Button {
                            onSelect(station)
                        } label: {
                            HStack(spacing: 12) {
                                LineBadge(line: station.line, size: 26)
                                Text(station.nombre)
                                    .font(.anden(16, weight: .medium))
                                    .foregroundStyle(Palette.textPrimary)
                                Spacer()
                            }
                        }
                        .listRowBackground(Palette.surface)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("Buscar estación")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Nombre de estación")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}
