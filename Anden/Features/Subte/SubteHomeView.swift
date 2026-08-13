import SwiftUI
import Observation

// ViewModel del home de subte. Carga las alertas de servicio y las agrupa por línea.
@MainActor
@Observable
final class SubteHomeViewModel {
    enum Phase: Equatable {
        case loading
        case ready
        case error(String)
    }

    private(set) var phase: Phase = .loading
    private(set) var alertsByLine: [String: [SubteAlertItem]] = [:]
    private var loaded = false

    var isConfigured: Bool { BASecrets.isConfigured }

    func loadIfNeeded() async {
        guard isConfigured, !loaded else { return }
        await load()
    }

    func load() async {
        guard isConfigured else { return }
        if alertsByLine.isEmpty { phase = .loading }
        do {
            let alerts = try await BAClient.shared.subteAlerts()
            var map: [String: [SubteAlertItem]] = [:]
            for a in alerts { map[a.line.routeId, default: []].append(a) }
            alertsByLine = map
            phase = .ready
            loaded = true
        } catch {
            phase = .error(SubteFormat.message(for: error))
        }
    }

    func alerts(for line: SubteLine) -> [SubteAlertItem] {
        alertsByLine[line.routeId] ?? []
    }

    // Alerta más grave de la línea (menor severity = más grave).
    func topAlert(for line: SubteLine) -> SubteAlertItem? {
        alerts(for: line).min(by: { $0.severity < $1.severity })
    }

    var allAlerts: [SubteAlertItem] {
        alertsByLine.values.flatMap { $0 }.sorted { $0.severity < $1.severity }
    }
}

// Home del subte: estado de servicio + lista de líneas A–E, H.
struct SubteHomeView: View {
    @State private var vm = SubteHomeViewModel()
    @Environment(\.scenePhase) private var scenePhase

    // Las 6 líneas troncales (sin Premetro).
    private var lines: [SubteLine] {
        SubteLine.all.filter { $0.routeId != "Premetro" }
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
        .navigationTitle("Subte")
        .navigationDestination(for: SubteLineRef.self) { ref in
            SubteLineView(line: ref.line)
        }
        .task { await vm.loadIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await vm.load() } }
        }
    }

    // MARK: - Contenido

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statusSection

                SectionHeaderView(
                    title: "Líneas",
                    subtitle: "Tocá una para ver estaciones y arribos"
                )

                VStack(spacing: 10) {
                    ForEach(lines) { line in
                        NavigationLink(value: SubteLineRef(line)) {
                            lineRow(line)
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

    // MARK: - Estado del servicio

    @ViewBuilder
    private var statusSection: some View {
        switch vm.phase {
        case .loading where vm.allAlerts.isEmpty:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small).tint(Palette.textSecondary)
                Text("Consultando estado del servicio…")
                    .font(.anden(13, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.surface))

        case .error(let message):
            HStack(spacing: 10) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.minorDelay)
                Text(message)
                    .font(.anden(13, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.surface))

        default:
            if vm.allAlerts.isEmpty {
                normalBanner
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeaderView(title: "Estado del servicio")
                    ForEach(vm.allAlerts) { alert in
                        alertCard(alert)
                    }
                }
            }
        }
    }

    private var normalBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Palette.onTime)
            Text("Toda la red funciona con normalidad")
                .font(.anden(14, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.onTime.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Palette.onTime.opacity(0.25), lineWidth: 0.5)
        )
    }

    private func alertCard(_ alert: SubteAlertItem) -> some View {
        let tint = SubteFormat.tint(for: alert)
        return HStack(alignment: .top, spacing: 12) {
            SubteBadge(line: alert.line, size: 36)
            VStack(alignment: .leading, spacing: 4) {
                Label(SubteFormat.shortStatus(alert), systemImage: alert.iconSystemName)
                    .font(.anden(13, weight: .bold))
                    .foregroundStyle(tint)
                Text(alert.text)
                    .font(.anden(13, weight: .regular))
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.surface))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(tint)
                .frame(width: 4)
                .padding(.vertical, 12)
                .padding(.leading, 2)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Fila de línea

    private func lineRow(_ line: SubteLine) -> some View {
        let top = vm.topAlert(for: line)
        return HStack(spacing: 14) {
            SubteBadge(line: line, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(line.nombre)
                    .font(.anden(17, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                if let top {
                    Label(SubteFormat.shortStatus(top), systemImage: top.iconSystemName)
                        .font(.anden(12, weight: .medium))
                        .foregroundStyle(SubteFormat.tint(for: top))
                        .lineLimit(1)
                } else {
                    Text("Servicio normal")
                        .font(.anden(12, weight: .medium))
                        .foregroundStyle(Palette.onTime)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.surface))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(line.color)
                .frame(width: 4)
                .padding(.vertical, 12)
                .padding(.leading, 2)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(line.nombre), \(top != nil ? SubteFormat.shortStatus(top!) : "servicio normal")")
    }

    // MARK: - Sin credenciales

    private var notConfigured: some View {
        EmptyStateView(
            icon: "key.horizontal",
            title: "Configurá la API de la Ciudad",
            message: "Faltan las credenciales de la API Transporte Buenos Aires. Agregá Secrets.plist para ver los arribos de subte."
        )
        .padding(.top, 60)
    }
}
