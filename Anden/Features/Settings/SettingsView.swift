import SwiftUI
import UIKit

// Ajustes: notificaciones, cómo funciona la app, datos y créditos.
struct SettingsView: View {
    private let settings = AppSettings.shared
    private let notifications = NotificationManager.shared

    @State private var isRequestingPermission = false
    @State private var permissionDeniedAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: notifBinding) {
                        Label("Avisarme de demoras", systemImage: "bell.badge.fill")
                    }
                    .tint(Palette.brand)
                    .disabled(isRequestingPermission)
                } footer: {
                    Text("Aviso de mejor esfuerzo. iOS decide cuándo revisa en segundo plano. Puede tardar minutos u horas.")
                }

                Section("Cómo funciona") {
                    InfoRow(icon: "antenna.radiowaves.left.and.right.slash", text: "Sin servidor propio no hay push en tiempo real. Los avisos son de mejor esfuerzo.")
                    InfoRow(icon: "arrow.clockwise", text: "El widget y el countdown se actualizan cuando abrís la app.")
                    InfoRow(icon: "exclamationmark.triangle", text: "Belgrano Norte y Urquiza no están en esta fuente de datos.")
                    NavigationLink("Ver el detalle completo") {
                        AboutView()
                    }
                    .font(.anden(14))
                }

                Section("Datos") {
                    InfoRow(icon: "server.rack", text: "Fuente: API pública de Trenes Argentinos (SOFSE).")
                    InfoRow(icon: "mappin.and.ellipse", text: "360 estaciones del AMBA.")
                    InfoRow(icon: "checkmark.seal", text: "Andén es una app no oficial.")
                }

                Section {
                    NavigationLink {
                        CreditsView()
                    } label: {
                        CreditsPreviewRow()
                    }
                }

                Section {
                    HStack {
                        Text("Versión")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
            }
            .navigationTitle("Ajustes")
            .alert("Notificaciones desactivadas", isPresented: $permissionDeniedAlert) {
                Button("Ir a Ajustes") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Ahora no", role: .cancel) {}
            } message: {
                Text("Activá las notificaciones para Andén en Ajustes del sistema.")
            }
        }
    }

    // Al activar, pide permiso. Si lo rechazan, ofrece ir a Ajustes.
    private var notifBinding: Binding<Bool> {
        Binding(
            get: { settings.notifDemorasEnabled },
            set: { newValue in
                if newValue {
                    isRequestingPermission = true
                    Task { @MainActor in
                        let granted = await notifications.requestAuthorization()
                        settings.notifDemorasEnabled = granted
                        if granted {
                            notifications.scheduleNext()
                        } else {
                            permissionDeniedAlert = true
                        }
                        isRequestingPermission = false
                    }
                } else {
                    settings.notifDemorasEnabled = false
                    notifications.cancelScheduled()
                }
            }
        )
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

private struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        Label {
            Text(text)
                .font(.anden(14))
                .foregroundStyle(Palette.textPrimary)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(Palette.brand)
        }
    }
}

private struct CreditsPreviewRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Palette.brand)
            VStack(alignment: .leading, spacing: 2) {
                Text("Créditos")
                    .font(.anden(15, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Text("Alan Daitch + Claude (Anthropic)")
                    .font(.anden(12))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }
}
