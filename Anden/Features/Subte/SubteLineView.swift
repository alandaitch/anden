import SwiftUI
import Observation

// ViewModel de una línea de subte. Carga las estaciones derivadas de los trenes activos.
@MainActor
@Observable
final class SubteLineViewModel {
    let line: SubteLine

    enum Phase: Equatable {
        case loading
        case ready
        case empty        // sin trenes en circulación ahora
        case error(String)
    }

    private(set) var phase: Phase = .loading
    private(set) var stations: [String] = []
    private var loaded = false

    var isConfigured: Bool { BASecrets.isConfigured }

    init(line: SubteLine) {
        self.line = line
    }

    func loadIfNeeded() async {
        guard isConfigured, !loaded else { return }
        await load()
    }

    func load() async {
        guard isConfigured else { return }
        if stations.isEmpty { phase = .loading }
        do {
            let list = try await BAClient.shared.subteStations(line: line)
            stations = list
            phase = list.isEmpty ? .empty : .ready
            loaded = true
        } catch {
            if stations.isEmpty {
                phase = .error(SubteFormat.message(for: error))
            }
        }
    }
}

// Lista de estaciones de una línea. Cada una lleva al tablero de arribos.
struct SubteLineView: View {
    let line: SubteLine
    @State private var vm: SubteLineViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(line: SubteLine) {
        self.line = line
        _vm = State(initialValue: SubteLineViewModel(line: line))
    }

    var body: some View {
        Group {
            if !vm.isConfigured {
                notConfigured
            } else {
                content
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle(line.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: SubteStationRef.self) { ref in
            SubteStationBoardView(stationName: ref.stationName, line: ref.line)
        }
        .task { await vm.loadIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await vm.load() } }
        }
    }

    // MARK: - Contenido

    @ViewBuilder
    private var content: some View {
        switch vm.phase {
        case .loading where vm.stations.isEmpty:
            LoadingStateView(message: "Buscando estaciones de \(line.nombre)…")
                .padding(.top, 40)

        case .empty:
            EmptyStateView(
                icon: "tram.fill",
                title: "Sin servicio ahora",
                message: "No hay trenes en circulación en \(line.nombre) en este momento. Probá de nuevo en un rato.",
                actionTitle: "Reintentar",
                action: { Task { await vm.load() } }
            )
            .padding(.top, 40)

        case .error(let message):
            ErrorStateView(message: message, retry: { Task { await vm.load() } })
                .padding(.top, 40)

        default:
            stationsList
        }
    }

    private var stationsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header

                Text("\(vm.stations.count) estaciones en servicio")
                    .font(.anden(13, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.leading, 4)

                VStack(spacing: 8) {
                    ForEach(Array(vm.stations.enumerated()), id: \.element) { index, name in
                        NavigationLink(value: SubteStationRef(routeId: line.routeId, stationName: name)) {
                            stationRow(name, isFirst: index == 0, isLast: index == vm.stations.count - 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .refreshable { await vm.load() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            SubteBadge(line: line, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(line.nombre)
                    .font(.anden(26, weight: .heavy))
                    .foregroundStyle(Palette.textPrimary)
                Text("Elegí una estación")
                    .font(.anden(14, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.surface))
    }

    // Fila de estación con un conector vertical estilo mapa de línea.
    private func stationRow(_ name: String, isFirst: Bool, isLast: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                // Segmento de línea vertical.
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(isFirst ? Color.clear : line.color)
                        .frame(width: 3)
                    Rectangle()
                        .fill(isLast ? Color.clear : line.color)
                        .frame(width: 3)
                }
                Circle()
                    .fill(Palette.surface)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(line.color, lineWidth: 3))
            }
            .frame(width: 18)

            Text(name)
                .font(.anden(16, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.surface))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Estación \(name), \(line.nombre)")
    }

    // MARK: - Sin credenciales

    private var notConfigured: some View {
        EmptyStateView(
            icon: "key.horizontal",
            title: "Configurá la API de la Ciudad",
            message: "Faltan las credenciales de la API Transporte Buenos Aires para mostrar las estaciones."
        )
        .padding(.top, 60)
    }
}
