import SwiftUI
import MapKit
import CoreLocation

// Mapa de red en vivo: trenes de una línea (o estación) moviéndose por GPS.
struct NetworkMapView: View {
    private enum Selection: Hashable {
        case line(Int)          // gerenciaId
        case station(Int)       // stationId

        var key: String {
            switch self {
            case .line(let id): return "line-\(id)"
            case .station(let id): return "station-\(id)"
            }
        }
    }

    @State private var selection: Selection
    @State private var trains: [Arrival] = []
    @State private var pins: [Station] = []
    @State private var isLoading = false
    @State private var loadFailed = false
    @State private var selectedArrival: Arrival?
    @State private var showSearch = false
    @State private var camera: MapCameraPosition = .region(Self.ambaRegion)

    private static let ambaRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -34.62, longitude: -58.44),
        span: MKCoordinateSpan(latitudeDelta: 0.55, longitudeDelta: 0.55)
    )

    // Líneas seleccionables: solo las que la API cubre.
    private var coveredLines: [TrainLine] { TrainLine.all.filter { $0.covered } }

    init() {
        // Arranca en Mitre (id 5) por default.
        let first = TrainLine.all.first(where: { $0.covered })?.id ?? 5
        _selection = State(initialValue: .line(first))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                mapLayer
                overlays
                VStack(spacing: 0) {
                    lineChips
                    Spacer()
                    legend
                }
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("Red en vivo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                StationSearchSheet { station in
                    selection = .station(station.id)
                    camera = .region(MKCoordinateRegion(
                        center: station.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
                    ))
                    showSearch = false
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
            .task(id: selection.key) {
                await loadCurrent(silent: false)
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 20_000_000_000)
                    if Task.isCancelled { break }
                    await loadCurrent(silent: true)
                }
            }
        }
    }

    // MARK: Mapa

    private var mapLayer: some View {
        Map(position: $camera) {
            ForEach(pins) { station in
                Annotation("", coordinate: station.coordinate, anchor: .center) {
                    Circle()
                        .fill(station.line.color.opacity(0.55))
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1))
                }
            }
            ForEach(trains) { train in
                if let coord = train.trainLocation {
                    Annotation("", coordinate: coord, anchor: .center) {
                        TrainAnnotation(line: train.line) {
                            selectedArrival = train
                        }
                    }
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: Overlays de estado

    @ViewBuilder
    private var overlays: some View {
        if isLoading && trains.isEmpty {
            LoadingStateView(message: "Buscando trenes en vivo…")
                .padding(.top, 120)
        } else if loadFailed && trains.isEmpty {
            ErrorStateView(message: "No pude cargar los trenes de la red.") {
                Task { await loadCurrent(silent: false) }
            }
            .padding(.top, 120)
        } else if !isLoading && trains.isEmpty {
            EmptyStateView(
                icon: "location.slash",
                title: "Sin trenes con GPS",
                message: emptyMessage
            )
            .padding(.top, 120)
        }
    }

    private var emptyMessage: String {
        switch selection {
        case .line(let id):
            let name = TrainLine.line(id: id).nombre
            return "Ninguna formación de \(name) reporta posición ahora. Casi la mitad de los servicios viaja sin GPS."
        case .station:
            return "Ningún tren cerca de esta estación reporta posición ahora."
        }
    }

    // MARK: Selector de línea

    private var lineChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(coveredLines) { line in
                    let isSelected = selection == .line(line.id)
                    Button {
                        selection = .line(line.id)
                        camera = .region(Self.ambaRegion)
                    } label: {
                        HStack(spacing: 6) {
                            LineBadge(line: line, size: 20)
                            Text(line.nombre)
                                .font(.anden(13, weight: .semibold))
                                .foregroundStyle(isSelected ? .white : Palette.textPrimary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            isSelected ? line.color : Palette.elevated,
                            in: Capsule()
                        )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: Leyenda

    private var legend: some View {
        HStack(spacing: 6) {
            if isLoading {
                ProgressView().scaleEffect(0.7)
            }
            Text(legendText)
                .font(.anden(12, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if !trains.isEmpty {
                LiveDot(active: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private var legendText: String {
        let count = trains.count
        switch selection {
        case .line(let id):
            let name = TrainLine.line(id: id).nombre
            return count == 0 ? name : "\(name) · \(count) en vivo"
        case .station(let id):
            let name = StationCatalog.shared.station(id: id)?.nombre ?? "Estación"
            return count == 0 ? name : "\(name) · \(count) en vivo"
        }
    }

    // MARK: Carga de datos

    private func loadCurrent(silent: Bool) async {
        if !silent { isLoading = true; loadFailed = false }
        defer { if !silent { isLoading = false } }

        switch selection {
        case .line(let lineId):
            await loadLine(lineId: lineId, silent: silent)
        case .station(let stationId):
            await loadStation(stationId: stationId, silent: silent)
        }
    }

    private func loadLine(lineId: Int, silent: Bool) async {
        let line = TrainLine.line(id: lineId)
        // Estaciones de la línea con servicio real, muestreadas.
        let stations = StationCatalog.shared.all
            .filter { $0.gerenciaId == lineId && $0.enRamalPublico && $0.tieneArribosHoy }
            .sorted { $0.distanciaObeliscoKm < $1.distanciaObeliscoKm }
        let sample = spread(stations, count: 6)
        pins = stations

        var collected: [String: Arrival] = [:]
        var anyError = false
        for station in sample {
            do {
                let list = try await SofseClient.shared.arrivals(stationId: station.id, limit: 6)
                merge(list, into: &collected, lineFilter: lineId)
            } catch {
                anyError = true
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        applyResult(Array(collected.values), fallbackLine: line, hadError: anyError)
    }

    private func loadStation(stationId: Int, silent: Bool) async {
        guard let station = StationCatalog.shared.station(id: stationId) else {
            applyResult([], fallbackLine: .unknown, hadError: true)
            return
        }
        pins = [station]
        do {
            let list = try await SofseClient.shared.arrivals(stationId: stationId, limit: 12)
            var collected: [String: Arrival] = [:]
            merge(list, into: &collected, lineFilter: nil)
            applyResult(Array(collected.values), fallbackLine: station.line, hadError: false)
        } catch {
            applyResult([], fallbackLine: station.line, hadError: true)
        }
    }

    // Junta arribos con GPS, dedup por serviceId, quedándose con el más próximo.
    private func merge(_ list: [Arrival], into collected: inout [String: Arrival], lineFilter: Int?) {
        for arrival in list {
            guard arrival.trainLocation != nil else { continue }
            if let lineFilter, arrival.lineId != lineFilter { continue }
            let key = arrival.serviceId ?? arrival.id
            if let existing = collected[key] {
                if arrival.secondsUntil < existing.secondsUntil { collected[key] = arrival }
            } else {
                collected[key] = arrival
            }
        }
    }

    private func applyResult(_ result: [Arrival], fallbackLine: TrainLine, hadError: Bool) {
        withAnimation(.linear(duration: 0.9)) {
            trains = result.sorted { $0.secondsUntil < $1.secondsUntil }
        }
        loadFailed = hadError && result.isEmpty
    }

    // Toma N estaciones repartidas a lo largo de la lista, no las primeras N.
    private func spread(_ stations: [Station], count: Int) -> [Station] {
        guard stations.count > count else { return stations }
        let step = Double(stations.count) / Double(count)
        return (0..<count).map { stations[Int(Double($0) * step)] }
    }
}

// Marcador de un tren en el mapa de red. Tap abre el detalle.
private struct TrainAnnotation: View {
    let line: TrainLine
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(line.color)
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                Image(systemName: "tram.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }
}

// Buscador de estación para centrar el mapa.
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
                        message: "Escribí el nombre para ver sus trenes en el mapa."
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
