import SwiftUI

// Estado vacío con ícono, título, mensaje y acción opcional.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    init(icon: String, title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 46, weight: .regular))
                .foregroundStyle(Palette.textSecondary)
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .font(.anden(19, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.anden(14, weight: .regular))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.anden(15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Palette.brand))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// Estado de carga con spinner y mensaje.
struct LoadingStateView: View {
    var message: String = "Buscando trenes…"

    init(message: String = "Buscando trenes…") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(Palette.brand)
            Text(message)
                .font(.anden(14, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

// Estado de error con reintento opcional.
struct ErrorStateView: View {
    let message: String
    var retry: (() -> Void)?

    init(message: String, retry: (() -> Void)? = nil) {
        self.message = message
        self.retry = retry
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(Palette.majorDelay)
                .symbolRenderingMode(.hierarchical)
            Text("No pudimos cargar")
                .font(.anden(18, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            Text(message)
                .font(.anden(14, weight: .regular))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
            if let retry {
                Button(action: retry) {
                    Label("Reintentar", systemImage: "arrow.clockwise")
                        .font(.anden(15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Palette.brand))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 24) {
        LoadingStateView()
        EmptyStateView(icon: "tram.fill", title: "Sin trenes ahora", message: "No hay arribos en vivo para esta estación.", actionTitle: "Recargar", action: {})
        ErrorStateView(message: "Revisá tu conexión e intentá de nuevo.", retry: {})
    }
    .background(Palette.background)
}
