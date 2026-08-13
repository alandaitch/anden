import SwiftUI
import Observation
import CoreLocation

// ViewModel del tablero de arribos de una parada de colectivo.
// Consulta forecastGTFS por StopCode. OJO: hoy el backend SOAP de BA devuelve 503,
// por eso maneja explícitamente serviceUnavailable como estado propio.
@MainActor
@Observable
final class ColectivoStopViewModel {
    let stop: BusStop

    enum Phase: Equatable {
        case loading
        case ready
        case empty                 // servicio OK pero sin arribos ahora
        case unavailable(String)   // backend de arribos caído (503)
        case error(String)
    }

    private(set) var phase: Phase = .loading
    private(set) var arrivals: [BusArrival] = []
    private(set) var lastUpdated: Date?

    private var refreshTask: Task<Void, Never>?
    private let interval: TimeInterval = 30

    var isConfigured: Bool { BASecrets.isConfigured }

    init(stop: BusStop) {
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
            let list = try await BAClient.shared.colectivoArrivals(stopCode: stop.code)
            arrivals = list
            phase = list.isEmpty ? .empty : .ready
            lastUpdated = Date()
        } catch let APIError.serviceUnavailable(message) {
            arrivals = []
            phase = .unavailable(message ?? "El servicio de arribos de colectivos de la Ciudad no responde ahora.")
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
    @Environment(\.scenePhase) private var scenePhase

    init(stop: BusStop) {
        _vm = State(initialValue: ColectivoStopViewModel(stop: stop))
    }

    private var stop: BusStop { vm.stop }

    var body: some View {
        Group {
            if !vm.isConfigured {
                notConfigured
            } else {
                scroll
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("Parada")
        .navigationBarTitleDisplayMode(.inline)
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
                    Text("Parada \(stop.code)")
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

        case .unavailable(let message):
            EmptyStateView(
                icon: "antenna.radiowaves.left.and.right.slash",
                title: "Arribos no disponibles",
                message: message,
                actionTitle: "Reintentar",
                action: { Task { await vm.load(initial: true) } }
            )
            .padding(.top, 30)

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

// Fila de un arribo de colectivo: badge de línea + destino + countdown + demora.
struct ColectivoArrivalRow: View {
    let arrival: BusArrival

    private var color: Color { BusLine.color(for: arrival.lineName) }

    var body: some View {
        HStack(spacing: 12) {
            BusLineBadge(lineName: arrival.lineName, size: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(arrival.destino.map { "a \($0)" } ?? "Línea \(arrival.lineName)")
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
                .fill(color)
                .frame(width: 4)
                .padding(.vertical, 12)
                .padding(.leading, 2)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Línea \(arrival.lineName)\(arrival.destino.map { " a \($0)" } ?? ""), \(Formatting.etaText(secondsUntil: arrival.secondsUntil)), \(arrival.delay.label)")
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
