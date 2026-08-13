import SwiftUI

// Alertas de servicio por línea. Filtro por línea + estados loading/vacío/error.
struct AlertsView: View {
    @State private var alerts: [ServiceAlert] = []
    @State private var selectedLine: TrainLine? = nil
    @State private var isLoading = true
    @State private var loadError: String? = nil

    private var filteredAlerts: [ServiceAlert] {
        guard let selectedLine else { return alerts }
        return alerts.filter { $0.lineId == selectedLine.id }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Alertas")
                .background(Palette.background)
                .task { await load() }
                .refreshable { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && alerts.isEmpty {
            LoadingStateView(message: "Buscando alertas…")
        } else if let loadError, alerts.isEmpty {
            ErrorStateView(message: loadError) {
                Task { await load() }
            }
        } else if alerts.isEmpty {
            EmptyStateView(
                icon: "checkmark.seal.fill",
                title: "Todo en orden",
                message: "Sin alertas. Todo el servicio normal."
            )
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    chipsRow

                    if filteredAlerts.isEmpty {
                        EmptyStateView(
                            icon: "line.3.horizontal.decrease.circle",
                            title: "Sin alertas para esta línea",
                            message: "Probá con otra línea o mirá todas.",
                            actionTitle: "Ver todas",
                            action: { selectedLine = nil }
                        )
                        .padding(.top, 24)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredAlerts) { alert in
                                AlertCard(alert: alert)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private var chipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                LineFilterChip(title: "Todas", color: Palette.brand, isSelected: selectedLine == nil) {
                    selectedLine = nil
                }
                ForEach(TrainLine.all) { line in
                    LineFilterChip(
                        title: line.shortCode,
                        color: line.color,
                        isSelected: selectedLine?.id == line.id
                    ) {
                        selectedLine = line
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func load() async {
        if alerts.isEmpty { isLoading = true }
        do {
            alerts = try await SofseClient.shared.alerts()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Tarjeta de alerta

private struct AlertCard: View {
    let alert: ServiceAlert

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: alert.iconSystemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(borderColor)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    LineBadge(line: TrainLine.line(id: alert.lineId ?? -1), size: 26)
                    Spacer()
                    Text(validityText)
                        .font(.anden(12))
                        .foregroundStyle(Palette.textSecondary)
                }

                Text(alert.content)
                    .font(.anden(15, weight: .medium))
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .andenCard()
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(borderColor, lineWidth: 1.5)
        )
    }

    private var borderColor: Color {
        switch alert.criticality {
        case 1: return Palette.majorDelay
        case 2: return Palette.minorDelay
        default: return Color(hex: "#3B82F6")
        }
    }

    private var validityText: String {
        switch (alert.validFrom, alert.validUntil) {
        case let (from?, until?):
            return "\(Formatting.clock(from)) a \(Formatting.clock(until)) hs"
        case let (from?, nil):
            return "Desde las \(Formatting.clock(from)) hs"
        case let (nil, until?):
            return "Hasta las \(Formatting.clock(until)) hs"
        default:
            return "Vigente"
        }
    }
}

// MARK: - Chip de filtro por línea

private struct LineFilterChip: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.anden(13, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? color : Palette.elevated)
                .foregroundStyle(isSelected ? Color.white : Palette.textPrimary)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(isSelected ? Color.clear : color.opacity(0.4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
