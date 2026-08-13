import SwiftUI
import MapKit
import CoreLocation

// "Cómo llego": buscador de destino con autocompletado (MKLocalSearchCompleter),
// sesgado al AMBA. Al elegir un lugar, delegamos el ruteo multimodal completo
// a Apple Maps con indicaciones de transporte público (MapsOpener.transit).
// No armamos rutas adentro de la app: es la forma honesta de resolver
// "cómo llego", porque Apple Maps ya tiene el transporte público de Buenos
// Aires (colectivo + subte + tren combinados) y nosotros no.
// Trae su propio NavigationStack: se monta como pantalla independiente.
struct ComoLlegoView: View {
    @State private var model = DestinationSearchModel()
    @State private var recents: [RecentDestination] = RecentDestinations.load()

    private var trimmedQuery: String {
        model.query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            content
                .background(Palette.background)
                .navigationTitle("Cómo llego")
                .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "¿A dónde vas?")
        }
    }

    // MARK: - Contenido según estado

    @ViewBuilder
    private var content: some View {
        if trimmedQuery.isEmpty {
            emptyOrRecents
        } else if let searchError = model.searchError {
            ErrorStateView(message: searchError, retry: { model.retry() })
                .padding(.top, 40)
        } else if model.isSearching && model.suggestions.isEmpty {
            LoadingStateView(message: "Buscando \"\(trimmedQuery)\"…")
                .padding(.top, 40)
        } else if model.suggestions.isEmpty {
            EmptyStateView(
                icon: "questionmark.circle",
                title: "Sin resultados",
                message: "No encontramos lugares para \"\(trimmedQuery)\"."
            )
            .padding(.top, 40)
        } else {
            suggestionsList
        }
    }

    // MARK: - Vacío: recientes + ejemplos

    private var emptyOrRecents: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if recents.isEmpty {
                    EmptyStateView(
                        icon: "signpost.right.and.left.fill",
                        title: "¿A dónde vas?",
                        message: "Buscá una dirección o un lugar. Te llevamos con indicaciones de transporte público en Apple Maps."
                    )
                    .padding(.top, 24)
                } else {
                    recentsSection
                }
                examplesSection
            }
            .padding(.horizontal, 16)
            .padding(.top, recents.isEmpty ? 0 : 16)
            .padding(.bottom, 32)
        }
    }

    private var recentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(title: "Recientes")
            VStack(spacing: 8) {
                ForEach(recents) { item in
                    recentRow(item)
                }
            }
        }
    }

    private func recentRow(_ item: RecentDestination) -> some View {
        Button {
            go(to: item.coordinate, name: item.title)
            recents = RecentDestinations.record(item, into: recents)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.anden(15, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                    if !item.subtitle.isEmpty {
                        Text(item.subtitle)
                            .font(.anden(12, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Palette.brand)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.surface))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Abre indicaciones en Apple Maps")
    }

    private static let exampleDestinations = [
        "Obelisco", "Aeroparque", "Ezeiza", "Tribunales", "Palermo", "Once"
    ]

    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(title: "Ejemplos", subtitle: "Tocá uno para buscarlo")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.exampleDestinations, id: \.self) { example in
                        Button {
                            model.query = example
                        } label: {
                            Text(example)
                                .font(.anden(13, weight: .semibold))
                                .foregroundStyle(Palette.textSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Palette.elevated))
                                .overlay(Capsule().strokeBorder(Palette.textSecondary.opacity(0.2), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Sugerencias

    private var suggestionsList: some View {
        List {
            ForEach(model.suggestions, id: \.self) { completion in
                Button {
                    select(completion)
                } label: {
                    suggestionRow(completion)
                }
                .buttonStyle(.plain)
            }
            .listRowBackground(Palette.surface)

            if let resolveError = model.resolveError {
                Section {
                    Text(resolveError)
                        .font(.anden(13, weight: .medium))
                        .foregroundStyle(Palette.majorDelay)
                }
                .listRowBackground(Palette.surface)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay(alignment: .top) {
            if model.isResolving {
                resolvingPill
                    .padding(.top, 8)
            }
        }
    }

    private func suggestionRow(_ completion: MKLocalSearchCompletion) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.brand)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(completion.title)
                    .font(.anden(15, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                if !completion.subtitle.isEmpty {
                    Text(completion.subtitle)
                        .font(.anden(12, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var resolvingPill: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Ubicando lugar…")
                .font(.anden(12, weight: .medium))
        }
        .foregroundStyle(Palette.textSecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Palette.elevated))
        .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
    }

    // MARK: - Acciones

    private func select(_ completion: MKLocalSearchCompletion) {
        Task {
            guard let item = await model.resolve(completion) else { return }
            let coordinate = item.placemark.coordinate
            let name = item.name ?? completion.title
            go(to: coordinate, name: name)

            let entry = RecentDestination(
                id: UUID(),
                title: name,
                subtitle: completion.subtitle,
                lat: coordinate.latitude,
                lng: coordinate.longitude
            )
            recents = RecentDestinations.record(entry, into: recents)
            model.query = ""
        }
    }

    private func go(to coordinate: CLLocationCoordinate2D, name: String) {
        MapsOpener.transit(to: coordinate, name: name)
    }
}

// MARK: - Recientes

// Destino reciente ya resuelto: guarda la coordenada, no hace falta
// re-buscarlo en Apple Maps.
struct RecentDestination: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let subtitle: String
    let lat: Double
    let lng: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

// Persistencia liviana de destinos recientes en UserDefaults.
enum RecentDestinations {
    private static let key = "comoLlego.recentDestinations"
    private static let limit = 6

    static func load() -> [RecentDestination] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([RecentDestination].self, from: data)) ?? []
    }

    // Mueve el ítem al frente (o lo agrega) y persiste.
    static func record(_ item: RecentDestination, into current: [RecentDestination]) -> [RecentDestination] {
        var items = current
        items.removeAll { $0.title == item.title && $0.subtitle == item.subtitle }
        items.insert(item, at: 0)
        if items.count > limit { items = Array(items.prefix(limit)) }
        save(items)
        return items
    }

    private static func save(_ items: [RecentDestination]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

#Preview {
    ComoLlegoView()
}
