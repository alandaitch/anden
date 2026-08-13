import SwiftUI

// Buscador de estaciones por nombre (substring, sin acento), con chip de línea
// y búsquedas recientes. Se asume empujada dentro del NavigationStack de Cercanas,
// que ya registra navigationDestination(for: Station.self).
struct SearchView: View {
    @State private var query = ""
    @State private var selectedLine: TrainLine?
    @State private var recentIds: [Int] = RecentSearches.load()

    private let catalog = StationCatalog.shared

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var results: [Station] {
        guard !trimmedQuery.isEmpty else { return [] }
        let base = catalog.search(trimmedQuery)
        guard let selectedLine else { return base }
        return base.filter { $0.line.id == selectedLine.id }
    }

    private var recentStations: [Station] {
        recentIds.compactMap { catalog.station(id: $0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            lineChips
            content
        }
        .background(Palette.background)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar estación")
        .navigationTitle("Buscador")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var lineChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TrainLine.all) { line in
                    lineChip(line)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func lineChip(_ line: TrainLine) -> some View {
        let isSelected = selectedLine?.id == line.id
        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                selectedLine = isSelected ? nil : line
            }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(line.color).frame(width: 8, height: 8)
                Text(line.shortCode).font(.anden(13, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(isSelected ? line.color.opacity(0.22) : Palette.elevated))
            .overlay(Capsule().stroke(isSelected ? line.color : .clear, lineWidth: 1.5))
            .foregroundStyle(isSelected ? line.color : Palette.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(line.nombre)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var content: some View {
        if trimmedQuery.isEmpty {
            if recentStations.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "Buscá tu estación",
                    message: "Encontrá cualquier estación del AMBA escribiendo su nombre."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        ForEach(recentStations) { station in
                            stationRow(station)
                        }
                    } header: {
                        SectionHeaderView(title: "Recientes")
                    }
                    .listRowBackground(Palette.surface)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        } else if results.isEmpty {
            EmptyStateView(
                icon: "questionmark.circle",
                title: "Sin resultados",
                message: "No encontramos estaciones para \"\(trimmedQuery)\"."
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(results) { station in
                    stationRow(station)
                }
                .listRowBackground(Palette.surface)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func stationRow(_ station: Station) -> some View {
        NavigationLink(value: station) {
            HStack(spacing: 12) {
                LineBadge(line: station.line, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.nombre)
                        .font(.anden(16, weight: .medium))
                        .foregroundStyle(Palette.textPrimary)
                    Text(station.line.nombre)
                        .font(.anden(13))
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .simultaneousGesture(TapGesture().onEnded {
            recordRecent(station.id)
        })
    }

    private func recordRecent(_ id: Int) {
        var ids = recentIds
        ids.removeAll { $0 == id }
        ids.insert(id, at: 0)
        if ids.count > 8 { ids = Array(ids.prefix(8)) }
        recentIds = ids
        RecentSearches.save(ids)
    }
}

// Persistencia liviana de búsquedas recientes (IDs de estación) en UserDefaults.
private enum RecentSearches {
    private static let key = "search.recentStationIds"

    static func load() -> [Int] {
        UserDefaults.standard.array(forKey: key) as? [Int] ?? []
    }

    static func save(_ ids: [Int]) {
        UserDefaults.standard.set(ids, forKey: key)
    }
}
