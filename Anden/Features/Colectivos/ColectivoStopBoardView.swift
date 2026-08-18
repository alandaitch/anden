import SwiftUI
import Observation
import CoreLocation

// ViewModel del tablero de arribos de una parada de colectivo.
// Usa la API OneBusAway de cuandosubo (pública, sin credenciales).
@MainActor
@Observable
final class ColectivoStopViewModel {
    let stop: ObaStopRef

    enum Phase: Equatable {
        case loading
        case ready
        case empty        // servicio OK pero sin arribos ahora
        case error(String)
    }

    private(set) var phase: Phase = .loading
    private(set) var arrivals: [BusArrivalOba] = []
    private(set) var lastUpdated: Date?

    private var refreshTask: Task<Void, Never>?
    private let interval: TimeInterval = 30

    init(stop: ObaStopRef) {
        self.stop = stop
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
        if initial || arrivals.isEmpty { phase = .loading }
        do {
            let list = try await ObaClient.shared.stopArrivals(stopId: stop.stopId)
            arrivals = list
            phase = list.isEmpty ? .empty : .ready
            lastUpdated = Date()
        } catch {
            if arrivals.isEmpty {
                phase = .error(SubteFormat.message(for: error))
            }
        }
    }
}

// Tablero de arribos de una parada de colectivo.
struct ColectivoStopBoardView: View {
    @State private var vm: ColectivoStopViewModel
    @State private var favTrigger = 0
    @Environment(\.scenePhase) private var scenePhase

    private let favorites = FavoritesStore.shared

    init(stop: ObaStopRef) {
        _vm = State(initialValue: ColectivoStopViewModel(stop: stop))
    }

    private var stop: ObaStopRef { vm.stop }
    private var isFavorite: Bool { favorites.isFavorite(.bondi, stop.stopId) }
    // El próximo colectivo con GPS en vivo (tripStatus.predicted). nil si es estimación.
    private var incomingBus: CLLocationCoordinate2D? {
        vm.arrivals.first(where: { $0.vehicleCoordinate != nil })?.vehicleCoordinate
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if !vm.arrivals.isEmpty {
                    StopVehicleMiniMap(
                        stop: stop.coordinate,
                        vehicle: incomingBus,
                        tint: Palette.brand,
                        vehicleIcon: "bus.fill"
                    )
                }
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .refreshable { await vm.refresh() }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("Parada")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    favorites.toggle(.bondi(stop))
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

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Palette.brand)
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: "bus.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(stop.name)
                        .font(.anden(22, weight: .heavy))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                    Text("Parada de colectivo")
                        .font(.anden(13, weight: .semibold))
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer(minLength: 0)
            }

            statusBar
            actionButtons
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
                Text("Buscando colectivos…")
                    .font(.anden(12, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
            }
        default:
            EmptyView()
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                MapsOpener.walk(to: stop.coordinate, name: stop.name)
            } label: {
                Label("Ir", systemImage: "figure.walk")
                    .font(.anden(14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Palette.brand))
            }
            .buttonStyle(.plain)

            Button {
                MapsOpener.transit(to: stop.coordinate, name: stop.name)
            } label: {
                Label("Cómo llego", systemImage: "tram.fill")
                    .font(.anden(14, weight: .bold))
                    .foregroundStyle(Palette.brand)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Palette.brand.opacity(0.14)))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Contenido

    @ViewBuilder
    private var content: some View {
        switch vm.phase {
        case .loading where vm.arrivals.isEmpty:
            LoadingStateView(message: "Buscando colectivos en esta parada…")
                .padding(.top, 40)

        case .empty:
            EmptyStateView(
                icon: "bus",
                title: "Sin colectivos ahora",
                message: "No hay arribos informados para esta parada en este momento.",
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Próximos colectivos")
                .font(.anden(13, weight: .bold))
                .foregroundStyle(Palette.textSecondary)
                .textCase(.uppercase)
                .padding(.leading, 4)

            ForEach(vm.arrivals) { arrival in
                ColectivoArrivalRow(arrival: arrival)
            }
        }
    }
}

// Fila de un arribo de colectivo: badge de línea + destino + countdown + VIVO/prog.
struct ColectivoArrivalRow: View {
    let arrival: BusArrivalOba

    private var color: Color { BusLine.color(for: arrival.lineShort) }

    var body: some View {
        HStack(spacing: 12) {
            BusLineBadge(lineName: arrival.lineShort, size: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(arrival.headsign.isEmpty ? "Línea \(arrival.lineShort)" : arrival.headsign)
                    .font(.anden(16, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if arrival.isLive {
                        LiveDot(active: true, color: Palette.onTime, size: 6)
                        Text("En vivo")
                            .font(.anden(12, weight: .bold))
                            .foregroundStyle(Palette.onTime)
                    } else {
                        Text("Programado")
                            .font(.anden(12, weight: .semibold))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    if let eta = arrival.eta {
                        Text("· \(Formatting.clock(eta))")
                            .font(.anden(12, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
            }

            Spacer(minLength: 8)

            CountdownText(secondsUntil: arrival.secondsUntil, big: false)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.surface))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 4)
                .padding(.vertical, 12)
                .padding(.leading, 2)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Línea \(arrival.lineShort)\(arrival.headsign.isEmpty ? "" : ", \(arrival.headsign)"), \(Formatting.etaText(secondsUntil: arrival.secondsUntil))\(arrival.isLive ? ", en vivo" : "")")
    }
}

// Badge de línea de colectivo. Sin color oficial: usa el tono determinístico de BusLine.
struct BusLineBadge: View {
    let lineName: String
    var size: CGFloat = 38

    private var color: Color { BusLine.color(for: lineName) }

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Text(lineName)
                    .font(.system(size: size * 0.4, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            .accessibilityElement()
            .accessibilityLabel("Línea \(lineName)")
    }
}
