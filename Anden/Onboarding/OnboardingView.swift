import SwiftUI

// Onboarding de 3 páginas: qué hace Andén, valor honesto de la ubicación,
// y CTA final que pide el permiso y cierra el onboarding.
// Integración la muestra como fullScreenCover mientras !AppSettings.shared.onboardingDone.
struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var didConfirm = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "tram.fill",
            title: "Tu tren, en vivo.",
            message: "Arribos en tiempo real de todas las líneas del AMBA. Demora real, andén y minutos exactos, sin vueltas."
        ),
        OnboardingPage(
            icon: "location.fill",
            title: "Sabemos dónde estás parado",
            message: "Con tu ubicación te mostramos directo las estaciones más cercanas y tu próximo tren. La usamos solo mientras usás la app. Nunca la compartimos."
        ),
        OnboardingPage(
            icon: "bolt.horizontal.fill",
            title: "Empecemos",
            message: "Activá tu ubicación para ver tus estaciones cercanas apenas abrís Andén."
        )
    ]

    private var isLastPage: Bool { currentPage == pages.count - 1 }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                skipBar

                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageDots
                    .padding(.top, 8)

                actionButtons
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
            }
        }
    }

    private var skipBar: some View {
        HStack {
            Spacer()
            if !isLastPage {
                Button("Omitir") {
                    finish(requestingPermission: false)
                }
                .font(.anden(15, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .padding(.trailing, 20)
            }
        }
        .frame(height: 44)
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? Palette.brand : Palette.textSecondary.opacity(0.3))
                    .frame(width: index == currentPage ? 22 : 8, height: 8)
            }
        }
        .animation(.snappy(duration: 0.25), value: currentPage)
    }

    @ViewBuilder
    private var actionButtons: some View {
        if isLastPage {
            VStack(spacing: 12) {
                Button {
                    didConfirm.toggle()
                    finish(requestingPermission: true)
                } label: {
                    Text("Activar ubicación")
                        .font(.anden(17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Palette.brand)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .sensoryFeedback(.success, trigger: didConfirm)

                Button("Ahora no") {
                    finish(requestingPermission: false)
                }
                .font(.anden(15, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
            }
        } else {
            Button {
                withAnimation(.snappy) { currentPage += 1 }
            } label: {
                Text("Seguir")
                    .font(.anden(17, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Palette.brand)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func finish(requestingPermission: Bool) {
        if requestingPermission {
            LocationManager.shared.requestPermission()
        }
        AppSettings.shared.onboardingDone = true
    }
}

private struct OnboardingPage {
    let icon: String
    let title: String
    let message: String
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Palette.brand.opacity(0.18))
                    .frame(width: 140, height: 140)
                Image(systemName: page.icon)
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(Palette.brand)
            }

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.anden(28, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                Text(page.message)
                    .font(.anden(16))
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
