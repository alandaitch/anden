import SwiftUI
import Observation

// ViewModel del tablero de una estación de subte. Refresca cada 20 s.
@MainActor
@Observable
final class SubteBoardViewModel {
    let stationName: String
    let line: SubteLine?

    enum Phase: Equatable {
        case loading
        case ready
        case empty        // sin trenes hacia esta estación ahora
        case error(String)
    }

    private(set) var phase: Phase = .loading
    private(set) var arrivals: [SubteArrival] = []
    private(set) var lastUpdated: Date?

    private var refreshTask: Task<Void, Never>?
    private let interval: TimeInterval = 20

    var isConfigured: Bool { BASecrets.isConfigured }

    init(stationName: String, line: SubteLine?) {
        self.stationName = stationName
        self.line = line
    }

    // Grupos por destino, en orden de llegada más próxima.
    struct Group: Identifiable {
        let id: String
        let destinationName: String
        let arrivals: [SubteArrival]
    }

    var groups: [Group] {
        var order: [String] = []
        var map: [String: [SubteArrival]] = [:]
        for a in arrivals {
            if map[a.destinationName] == nil { order.append(a.destinationName) }
            map[a.destinationName, default: []].append(a)
        }
        return order.map { dest in
            Group(
                id: dest,
                destinationName: dest,
                arrivals: (map[dest] ?? []).sorted { $0.secondsUntil < $1.secondsUntil }
            )
        }
    }

    // MARK: - Ciclo de vida

    func onAppear() {
        if arrivals.isEmpty {
            Task { await load(initial: true) }
        }
        startAutoRefresh()
    }

    func onDisappear() {
        stopAutoRefresh()
    }

    func startAutoRefresh() {
        guard isConfigured else { return }
        stopAutoRefresh()
        let interval = interval
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                if Task.isCancelled { break }
                await self?.load(initial: false)
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Carga

    func refresh() async {
        await load(initial: false)
    }

    func load(initial: Bool) async {
        guard isConfigured else { return }
        if initial || arrivals.isEmpty { phase = .loading }
        do {
            let all = try await BAClient.shared.subteArrivals(stationName: stationName)
            let filtered: [SubteArrival]
            if let line {
                filtered = all.filter { $0.line.routeId == line.routeId }
            } else {
                filtered = all
            }
            arrivals = filtered
            phase = filtered.isEmpty ? .empty : .ready
            lastUpdated = Date()
        } catch {
            // Conservamos lo que ya se mostró; solo rompemos si no hay nada.
            if arrivals.isEmpty {
                phase = .error(SubteFormat.message(for: error))
            }
        }
    }
}

// Tablero de arribos de una estación de subte.
struct SubteStationBoardView: View {
    @State private var vm: SubteBoardViewModel
    @State private var favTrigger = 0
    @Environment(\.scenePhase) private var scenePhase

    private let favorites = FavoritesStore.shared

    init(stationName: String, line: SubteLine? = nil) {
        _vm = State(initialValue: SubteBoardViewModel(stationName: stationName, line: line))
    }

    private var stationName: String { vm.stationName }
    private var subteStation: SubteStation? { SubteCatalog.shared.station(name: stationName, line: vm.line) }
    private var isFavorite: Bool { subteStation.map { favorites.isFavorite(.subte, $0.id) } ?? false }

    var body: some View {
        Group {
            if !vm.isConfigured {
                notConfigured
            } else {
                scroll
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle(stationName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let st = subteStation {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        favorites.toggle(.subte(st))
                        favTrigger += 1
                    } label: {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(isFavorite ? Palette.minorDelay : Palette.textSecondary)
                            .symbolEffect(.bounce, value: favTrigger)
                    }
                    .accessibilityLabel(isFavorite ? "Quitar de favoritos" : "Agregar a favoritos")
                }
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: favTrigger)
        .onAppear { vm.onAppear() }
        .onDisappear { vm.onDisappear() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                vm.startAutoRefresh()
                Task { await vm.load(initial: false) }
            case .background, .inactive:
                vm.stopAutoRefresh()
            @unknown default:
                break
            }
        }
    }

    private var scroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .refreshable { await vm.refresh() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                if let line = vm.line {
                    SubteBadge(line: line, size: 52)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(stationName)
                        .font(.anden(26, weight: .heavy))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    if let line = vm.line {
                        Text(line.nombre)
                            .font(.anden(14, weight: .semibold))
                            .foregroundStyle(line.color)
                    }
                }
                Spacer(minLength: 0)
            }
            statusBar
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.surface))
    }

    @ViewBuilder
    private var statusBar: some View {
        switch vm.phase {
        case .ready:
            HStack(spacing: 8) {
                LiveDot(active: true, color: Palette.onTime, size: 7)
                Text("En vivo")
                    .font(.anden(13, weight: .semibold))
                    .foregroundStyle(Palette.onTime)
                if let ts = vm.lastUpdated {
                    Text("· actualizado \(Formatting.clock(ts))")
                        .font(.anden(12, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        case .loading:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small).tint(Palette.textSecondary)
                Text("Buscando trenes…")
                    .font(.anden(12, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Contenido

    @ViewBuilder
    private var content: some View {
        switch vm.phase {
        case .loading where vm.arrivals.isEmpty:
            LoadingStateView(message: "Buscando trenes en \(stationName)…")
                .padding(.top, 40)

        case .empty:
            EmptyStateView(
                icon: "tram.fill",
                title: "Sin trenes ahora",
                message: "No hay arribos en vivo para \(stationName) en este momento.",
                actionTitle: "Reintentar",
                action: { Task { await vm.load(initial: true) } }
            )
            .padding(.top, 40)

        case .error(let message):
            ErrorStateView(message: message, retry: { Task { await vm.load(initial: true) } })
                .padding(.top, 40)

        default:
            board
        }
    }

    private var board: some View {
        ForEach(vm.groups) { group in
            VStack(alignment: .leading, spacing: 10) {
                Text("Hacia \(group.destinationName)")
                    .font(.anden(13, weight: .bold))
                    .foregroundStyle(Palette.textSecondary)
                    .textCase(.uppercase)
                    .padding(.leading, 4)

                if let first = group.arrivals.first {
                    heroCard(first)
                }
                ForEach(group.arrivals.dropFirst().prefix(4)) { arrival in
                    SubteArrivalRow(arrival: arrival)
                }
            }
            .padding(.bottom, 4)
        }
    }

    // Tarjeta principal del próximo tren del grupo, con countdown grande.
    private func heroCard(_ arrival: SubteArrival) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                SubteBadge(line: arrival.line, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Próximo")
                        .font(.anden(11, weight: .semibold))
                        .foregroundStyle(Palette.textSecondary)
                        .textCase(.uppercase)
                    Text(arrival.destinationName)
                        .font(.anden(18, weight: .bold))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                LiveDot(active: true, color: Palette.onTime, size: 7)
            }

            HStack(alignment: .firstTextBaseline) {
                CountdownText(secondsUntil: arrival.secondsUntil, big: true)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 6) {
                    DelayPill(arrival.delay)
                    Text("Hora \(Formatting.clock(arrival.eta))")
                        .font(.anden(12, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.surface))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(arrival.line.color)
                .frame(width: 5)
                .padding(.vertical, 16)
                .padding(.leading, 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Próximo a \(arrival.destinationName), \(Formatting.etaText(secondsUntil: arrival.secondsUntil)), \(arrival.delay.label)")
    }

    // MARK: - Sin credenciales

    private var notConfigured: some View {
        EmptyStateView(
            icon: "key.horizontal",
            title: "Configurá la API de la Ciudad",
            message: "Faltan las credenciales de la API Transporte Buenos Aires para mostrar los arribos."
        )
        .padding(.top, 60)
    }
}

// Fila compacta de un arribo de subte.
struct SubteArrivalRow: View {
    let arrival: SubteArrival

    var body: some View {
        HStack(spacing: 12) {
            SubteBadge(line: arrival.line, size: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(arrival.destinationName)
                    .font(.anden(16, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                Text("Hora \(Formatting.clock(arrival.eta))")
                    .font(.anden(12, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                CountdownText(secondsUntil: arrival.secondsUntil, big: false)
                DelayPill(arrival.delay, compact: true)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.surface))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(arrival.line.color)
                .frame(width: 4)
                .padding(.vertical, 12)
                .padding(.leading, 2)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(arrival.line.nombre) a \(arrival.destinationName), \(Formatting.etaText(secondsUntil: arrival.secondsUntil)), \(arrival.delay.label)")
    }
}
