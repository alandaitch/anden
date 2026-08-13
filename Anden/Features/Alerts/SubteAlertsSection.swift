import SwiftUI

// Sección reutilizable de alertas de subte. Se carga sola desde BAClient.
// Estados: loading / vacío / error. Pensada para insertarse dentro de AlertsView,
// como sub-sección debajo de las alertas de tren.
struct SubteAlertsSection: View {
    @State private var alerts: [SubteAlertItem] = []
    @State private var isLoading = true
    @State private var loadError: String? = nil

    var body: some View {
        content
            .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && alerts.isEmpty {
            LoadingStateView(message: "Buscando alertas de subte…")
        } else if let loadError, alerts.isEmpty {
            ErrorStateView(message: loadError) {
                Task { await load() }
            }
        } else if alerts.isEmpty {
            EmptyStateView(
                icon: "checkmark.seal.fill",
                title: "Subte sin alertas",
                message: "Servicio normal en todas las líneas."
            )
        } else {
            LazyVStack(spacing: 12) {
                ForEach(alerts) { alert in
                    SubteAlertCard(alert: alert)
                }
            }
        }
    }

    private func load() async {
        if alerts.isEmpty { isLoading = true }
        do {
            alerts = try await BAClient.shared.subteAlerts()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Tarjeta de alerta de subte

private struct SubteAlertCard: View {
    let alert: SubteAlertItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: alert.iconSystemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(borderColor)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 8) {
                SubteLineBadge(line: alert.line, size: 26)

                Text(alert.text)
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

    // Mismo criterio de color que AlertCard (Alertas de tren): grave=rojo, demoras=ámbar, resto=azul info.
    private var borderColor: Color {
        switch alert.effect {
        case 1: return Palette.majorDelay   // NO_SERVICE
        case 4: return Palette.minorDelay   // SIGNIFICANT_DELAYS
        default: return Color(hex: "#3B82F6")
        }
    }
}

// MARK: - Badge de línea de subte

// Mismo lenguaje visual que LineBadge (core, específico de TrainLine), pero para SubteLine.
// No reusa LineBadge porque su firma está atada a TrainLine.
private struct SubteLineBadge: View {
    let line: SubteLine
    var size: CGFloat = 28

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(line.color)
            .overlay(
                Text(line.letra)
                    .font(.system(size: size * 0.44, weight: .heavy, design: .rounded))
                    .kerning(size * 0.02)
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, 1)
            )
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            .accessibilityElement()
            .accessibilityLabel("Línea \(line.nombre)")
    }
}

#Preview {
    ScrollView {
        SubteAlertsSection()
            .padding(.horizontal, 16)
            .padding(.top, 8)
    }
    .background(Palette.background)
}
