import SwiftUI

// Tarjeta de créditos. Pedido explícito de Alan.
struct CreditsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Palette.brand, Color(hex: "#1E7FD4")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 84, height: 84)
                            .shadow(color: Palette.brand.opacity(0.4), radius: 16, x: 0, y: 8)
                        Image(systemName: "tram.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Text("Andén")
                        .font(.anden(28, weight: .bold))
                        .foregroundStyle(Palette.textPrimary)
                    Text("Tu tren, en vivo.")
                        .font(.anden(15))
                        .foregroundStyle(Palette.textSecondary)
                }
                .padding(.top, 24)

                VStack(spacing: 16) {
                    HStack(spacing: 6) {
                        LiveDot(active: true)
                        Text("Hecho por Alan Daitch + Claude (Anthropic).")
                            .font(.anden(14, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 14) {
                        creditRow(icon: "person.fill", name: "Alan Daitch", role: "Producto y diseño")
                        Divider().overlay(Palette.textSecondary.opacity(0.15))
                        creditRow(icon: "sparkles", name: "Claude (Anthropic)", role: "Ingeniería")
                    }
                    .andenCard()
                }

                Text("Andén es un proyecto independiente. No tiene relación con SOFSE, Trenes Argentinos ni el Estado.")
                    .font(.anden(12))
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.background)
        .navigationTitle("Créditos")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func creditRow(icon: String, name: String, role: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Palette.brand.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .foregroundStyle(Palette.brand)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.anden(15, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Text(role)
                    .font(.anden(12))
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
        }
    }
}
