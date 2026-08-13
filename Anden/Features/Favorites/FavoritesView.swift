import SwiftUI

// Favoritos con contexto (casa/trabajo). Cada uno con su próximo arribo.
struct FavoritesView: View {
    // Callback opcional para mandar al buscador desde el estado vacío.
    // Si integración no lo pasa, el CTA queda oculto.
    var onSearchTapped: (() -> Void)? = nil

    private let store = FavoritesStore.shared

    @State private var nextArrivals: [Int: Arrival] = [:]
    @State private var removalTrigger = 0

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Favoritos")
                .background(Palette.background)
                .navigationDestination(for: Station.self) { station in
                    StationBoardView(station: station)
                }
                .task { await refreshAll() }
                .refreshable { await refreshAll() }
                .sensoryFeedback(.impact, trigger: removalTrigger)
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.favorites.isEmpty {
            EmptyStateView(
                icon: "star",
                title: "Sin favoritos",
                message: "Marcá una estación como favorita para verla acá, con su próximo tren.",
                actionTitle: onSearchTapped != nil ? "Buscar estaciones" : nil,
                action: onSearchTapped
            )
        } else {
            List {
                if let primary = store.contextualPrimary() {
                    Section {
                        NavigationLink(value: primary) {
                            StationRowPreview(
                                station: primary,
                                nextArrival: nextArrivals[primary.id],
                                distance: nil
                            )
                            .padding(.vertical, 6)
                        }
                        .listRowBackground(Palette.elevated)
                    } header: {
                        SectionHeaderView(title: "Estación del momento", subtitle: contextSubtitle(for: primary))
                    }
                }

                Section {
                    ForEach(store.favorites) { station in
                        NavigationLink(value: station) {
                            StationRowPreview(
                                station: station,
                                nextArrival: nextArrivals[station.id],
                                distance: nil
                            )
                        }
                        .contextMenu {
                            roleMenu(for: station)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.toggle(station.id)
                                removalTrigger += 1
                            } label: {
                                Label("Quitar", systemImage: "star.slash.fill")
                            }
                        }
                    }
                } header: {
                    SectionHeaderView(title: "Tus favoritos")
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private func roleMenu(for station: Station) -> some View {
        let currentRole = store.role(for: station.id)

        Button {
            store.setRole(.home, for: station.id)
        } label: {
            Label(currentRole == .home ? "Es tu casa" : "Marcar como casa", systemImage: "house.fill")
        }

        Button {
            store.setRole(.work, for: station.id)
        } label: {
            Label(currentRole == .work ? "Es tu trabajo" : "Marcar como trabajo", systemImage: "briefcase.fill")
        }

        if currentRole != .none {
            Button {
                store.setRole(.none, for: station.id)
            } label: {
                Label("Quitar rol", systemImage: "xmark.circle")
            }
        }

        Divider()

        Button(role: .destructive) {
            store.toggle(station.id)
            removalTrigger += 1
        } label: {
            Label("Quitar de favoritos", systemImage: "star.slash.fill")
        }
    }

    private func contextSubtitle(for station: Station) -> String? {
        switch store.role(for: station.id) {
        case .home: return "Tu casa"
        case .work: return "Tu trabajo"
        case .none: return nil
        }
    }

    // Trae el próximo arribo de cada favorito, en paralelo.
    private func refreshAll() async {
        let stations = store.favorites
        guard !stations.isEmpty else { return }

        await withTaskGroup(of: (Int, Arrival?).self) { group in
            for station in stations {
                group.addTask {
                    let arrival = (try? await SofseClient.shared.arrivals(stationId: station.id, limit: 1))?.first
                    return (station.id, arrival)
                }
            }
            for await (id, arrival) in group {
                nextArrivals[id] = arrival
            }
        }
    }
}
