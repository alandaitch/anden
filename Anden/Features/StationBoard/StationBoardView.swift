import SwiftUI

// Pantalla estrella: tablero de arribos de una estación.
struct StationBoardView: View {
    @State private var vm: StationBoardViewModel
    @State private var favTrigger = 0
    @Environment(\.scenePhase) private var scenePhase

    private let favorites = FavoritesStore.shared

    init(station: Station) {
        _vm = State(initialValue: StationBoardViewModel(station: station))
    }

    private var station: Station { vm.station }
    private var isFavorite: Bool { favorites.isFavorite(station.id) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16, pinnedViews: []) {
                header

                if vm.hasMultipleGroups && vm.phase != .unavailable {
                    groupChips
                }

                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(station.nombre)
                    .font(.anden(16, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                favoriteButton
            }
        }
        .refreshable { await vm.refresh() }
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
                LineBadge(line: station.line, size: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(station.nombre)
                        .font(.anden(28, weight: .heavy))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)

                    HStack(spacing: 8) {
                        Text(station.line.nombre)
                            .font(.anden(14, weight: .semibold))
                            .foregroundStyle(station.line.color)
                        if let andenes = station.andenes, andenes > 0 {
                            Text("·")
                                .foregroundStyle(Palette.textSecondary)
                            Label("\(andenes) andenes", systemImage: "figure.walk")
                                .font(.anden(13, weight: .medium))
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            statusBar
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Palette.surface)
        )
    }

    private var favoriteButton: some View {
        Button {
            favorites.toggle(station.id)
            favTrigger += 1
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isFavorite ? Palette.minorDelay : Palette.textSecondary)
                .symbolEffect(.bounce, value: favTrigger)
        }
        .accessibilityLabel(isFavorite ? "Quitar de favoritos" : "Agregar a favoritos")
    }

    @ViewBuilder
    private var statusBar: some View {
        switch vm.phase {
        case .live:
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
        case .scheduled:
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 12, weight: .semibold))
                Text("Horario programado — sin datos en vivo")
                    .font(.anden(12, weight: .semibold))
            }
            .foregroundStyle(Palette.minorDelay)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Palette.minorDelay.opacity(0.14)))
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

    // MARK: - Chips de sentido

    private var groupChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "Todos", id: nil)
                ForEach(vm.groups) { group in
                    chip(title: group.destinationName.isEmpty ? group.ramalName : group.destinationName, id: group.id)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(title: String, id: String?) -> some View {
        let selected = vm.selectedGroupId == id
        return Button {
            vm.selectGroup(id)
        } label: {
            Text(title)
                .font(.anden(13, weight: .semibold))
                .foregroundStyle(selected ? .white : Palette.textSecondary)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(selected ? Palette.brand : Palette.surface)
                )
                .overlay(
                    Capsule().strokeBorder(Palette.textSecondary.opacity(selected ? 0 : 0.2), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Contenido

    @ViewBuilder
    private var content: some View {
        switch vm.phase {
        case .loading where vm.arrivals.isEmpty:
            LoadingStateView(message: "Buscando trenes en \(station.nombre)…")
                .padding(.top, 40)

        case .unavailable:
            EmptyStateView(
                icon: "exclamationmark.triangle",
                title: "Línea no disponible",
                message: "Esta línea no está disponible en la fuente de datos. La operan otras empresas y no publican arribos en vivo."
            )
            .padding(.top, 40)

        case .empty:
            EmptyStateView(
                icon: "tram.fill",
                title: "Sin trenes ahora",
                message: "No hay arribos en vivo ni horarios para esta estación en este momento.",
                actionTitle: "Reintentar",
                action: { Task { await vm.retry() } }
            )
            .padding(.top, 40)

        case .error(let message):
            ErrorStateView(message: message, retry: { Task { await vm.retry() } })
                .padding(.top, 40)

        default:
            arrivalsList
        }
    }

    @ViewBuilder
    private var arrivalsList: some View {
        let showGroupHeaders = vm.selectedGroupId == nil && vm.hasMultipleGroups
        ForEach(vm.displayGroups) { group in
            if showGroupHeaders {
                Text("Hacia \(group.destinationName)")
                    .font(.anden(13, weight: .bold))
                    .foregroundStyle(Palette.textSecondary)
                    .textCase(.uppercase)
                    .padding(.top, 4)
                    .padding(.leading, 4)
            }
            ForEach(group.arrivals) { arrival in
                NavigationLink {
                    ServiceDetailView(arrival: arrival)
                } label: {
                    ArrivalRow(arrival: arrival)
                }
                .buttonStyle(.plain)
                .opacity(vm.isScheduled ? 0.92 : 1)
            }
        }

        if vm.isScheduled {
            Text("Los horarios pueden variar. Sin GPS ni demora en vivo.")
                .font(.anden(12, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, 6)
                .padding(.horizontal, 4)
        }
    }
}
