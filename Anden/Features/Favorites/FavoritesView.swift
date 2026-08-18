import SwiftUI

// Favoritos multi-modo (tren, subte, colectivo, bici) con contexto casa/trabajo.
// Cada fila muestra su próximo arribo y navega a su tablero.
struct FavoritesView: View {
    var onSearchTapped: (() -> Void)? = nil

    private let store = FavoritesStore.shared

    // Subtítulo "próximo arribo" por favorito (item.id -> texto).
    @State private var subtitles: [String: String] = [:]
    // EcoBici en vivo por id, para navegar y mostrar disponibilidad.
    @State private var ecobiciLive: [String: EcobiciStation] = [:]
    @State private var removalTrigger = 0

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Favoritos")
                .background(Palette.background)
                .navigationDestination(for: FavoriteItem.self) { item in
                    destination(for: item)
                }
                .task { await refreshAll() }
                .refreshable { await refreshAll() }
                .sensoryFeedback(.impact, trigger: removalTrigger)
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.items.isEmpty {
            EmptyStateView(
                icon: "star",
                title: "Sin favoritos",
                message: "Marcá cualquier parada como favorita (tren, subte, colectivo o bici) para verla acá con su próximo arribo.",
                actionTitle: onSearchTapped != nil ? "Buscar paradas" : nil,
                action: onSearchTapped
            )
        } else {
            List {
                if let primary = store.contextualPrimary() {
                    Section {
                        favoriteLink(primary)
                    } header: {
                        SectionHeaderView(title: "Del momento", subtitle: contextSubtitle(for: primary))
                    }
                }

                Section {
                    ForEach(store.items) { item in
                        favoriteLink(item)
                            .contextMenu { roleMenu(for: item) }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.remove(item.mode, item.refId)
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

    private func favoriteLink(_ item: FavoriteItem) -> some View {
        NavigationLink(value: item) {
            FavoriteRow(item: item, subtitle: subtitles[item.id])
                .padding(.vertical, 4)
        }
        .listRowBackground(Palette.elevated)
    }

    // MARK: - Navegación por modo

    @ViewBuilder
    private func destination(for item: FavoriteItem) -> some View {
        switch item.mode {
        case .tren:
            if let st = StationCatalog.shared.station(id: Int(item.refId) ?? -1) {
                StationBoardView(station: st)
            } else {
                unavailable
            }
        case .subte:
            SubteStationBoardView(stationName: item.name,
                                  line: item.routeId.map { SubteLine.line(routeId: $0) })
        case .bondi:
            ColectivoStopBoardView(stop: ObaStopRef(stopId: item.refId, name: item.name, lat: item.lat, lng: item.lng))
        case .bici:
            EcobiciStopDetailView(station: ecobiciLive[item.refId] ?? stubEcobici(item))
        }
    }

    private var unavailable: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 26))
                .foregroundStyle(Palette.textSecondary)
            Text("No pudimos abrir esta parada.")
                .font(.anden(14, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
    }

    private func stubEcobici(_ item: FavoriteItem) -> EcobiciStation {
        EcobiciStation(id: item.refId, name: item.name, lat: item.lat, lng: item.lng,
                       capacity: 0, bikesMechanical: 0, bikesEbike: 0, bikesTotal: 0,
                       docksAvailable: 0, status: "IN_SERVICE", lastReported: Date())
    }

    // MARK: - Menú de rol

    @ViewBuilder
    private func roleMenu(for item: FavoriteItem) -> some View {
        let currentRole = store.role(item.mode, item.refId)

        Button {
            store.setRole(.home, item.mode, item.refId)
        } label: {
            Label(currentRole == .home ? "Es tu casa" : "Marcar como casa", systemImage: "house.fill")
        }
        Button {
            store.setRole(.work, item.mode, item.refId)
        } label: {
            Label(currentRole == .work ? "Es tu trabajo" : "Marcar como trabajo", systemImage: "briefcase.fill")
        }
        if currentRole != .none {
            Button {
                store.setRole(.none, item.mode, item.refId)
            } label: {
                Label("Quitar rol", systemImage: "xmark.circle")
            }
        }
        Divider()
        Button(role: .destructive) {
            store.remove(item.mode, item.refId)
            removalTrigger += 1
        } label: {
            Label("Quitar de favoritos", systemImage: "star.slash.fill")
        }
    }

    private func contextSubtitle(for item: FavoriteItem) -> String? {
        switch store.role(item.mode, item.refId) {
        case .home: return "Tu casa"
        case .work: return "Tu trabajo"
        case .none: return nil
        }
    }

    // MARK: - Carga de datos

    private func refreshAll() async {
        let items = store.items
        guard !items.isEmpty else { return }

        // EcoBici: una sola llamada para todas las bici favoritas.
        if items.contains(where: { $0.mode == .bici }),
           let stations = try? await BAClient.shared.ecobiciStations() {
            var byId: [String: EcobiciStation] = [:]
            for st in stations { byId[st.id] = st }
            ecobiciLive = byId
        }

        await withTaskGroup(of: (String, String?).self) { group in
            for item in items {
                group.addTask {
                    (item.id, await Self.subtitle(for: item))
                }
            }
            for await (id, text) in group {
                if let text { subtitles[id] = text }
            }
        }
    }

    // Próximo arribo (o disponibilidad, en bici) resuelto por el cliente de cada modo.
    private static func subtitle(for item: FavoriteItem) async -> String? {
        switch item.mode {
        case .tren:
            guard let id = Int(item.refId),
                  let a = try? await SofseClient.shared.arrivals(stationId: id, limit: 1).first else { return nil }
            return "\(Formatting.etaText(secondsUntil: a.secondsUntil)) · a \(a.destinationName)"
        case .subte:
            guard let a = try? await BAClient.shared.subteArrivals(stationName: item.name).first else { return nil }
            return "\(Formatting.etaText(secondsUntil: a.secondsUntil)) · a \(a.destinationName)"
        case .bondi:
            guard let a = try? await ObaClient.shared.stopArrivals(stopId: item.refId).first else { return nil }
            let estado = a.isLive ? "en vivo" : "prog"
            return "\(a.lineShort) · \(Formatting.etaText(secondsUntil: a.secondsUntil)) \(estado)"
        case .bici:
            return nil
        }
    }
}

// MARK: - Fila

private struct FavoriteRow: View {
    let item: FavoriteItem
    let subtitle: String?

    private var accent: Color {
        switch item.mode {
        case .tren, .subte: return Color(hex: item.lineColorHex ?? "#3A4A63")
        case .bondi: return Palette.brand
        case .bici: return Color(hex: "#0FA3A3")
        }
    }

    private var modeTag: String {
        switch item.mode {
        case .tren: return "Tren"
        case .subte: return "Subte"
        case .bondi: return "Colectivo"
        case .bici: return "EcoBici"
        }
    }

    private var iconName: String {
        switch item.mode {
        case .tren, .subte: return "tram.fill"
        case .bondi: return "bus.fill"
        case .bici: return "bicycle"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            badge
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.anden(16, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(modeTag)
                        .font(.anden(12, weight: .semibold))
                        .foregroundStyle(accent)
                    if item.role != .none {
                        Image(systemName: item.role == .home ? "house.fill" : "briefcase.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.anden(13, weight: .medium))
                        .foregroundStyle(Palette.onTime)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var badge: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(accent)
            .frame(width: 46, height: 46)
            .overlay {
                if let label = item.lineLabel, !label.isEmpty {
                    Text(label)
                        .font(.anden(18, weight: .heavy))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.horizontal, 2)
                } else {
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
    }
}
