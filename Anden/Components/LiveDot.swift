import SwiftUI

// Punto "en vivo" que pulsa con un halo. Se detiene si active == false.
struct LiveDot: View {
    var active: Bool = true
    var color: Color = Palette.onTime
    var size: CGFloat = 8

    @State private var pulse = false

    init(active: Bool = true, color: Color = Palette.onTime, size: CGFloat = 8) {
        self.active = active
        self.color = color
        self.size = size
    }

    var body: some View {
        ZStack {
            if active {
                Circle()
                    .fill(color.opacity(0.35))
                    .frame(width: size * 2.4, height: size * 2.4)
                    .scaleEffect(pulse ? 1.0 : 0.4)
                    .opacity(pulse ? 0.0 : 0.9)
            }
            Circle()
                .fill(active ? color : Palette.noData)
                .frame(width: size, height: size)
        }
        .frame(width: size * 2.4, height: size * 2.4)
        .onAppear {
            guard active else { return }
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 24) {
        LiveDot(active: true)
        LiveDot(active: false)
        LiveDot(active: true, color: Palette.minorDelay, size: 12)
    }
    .padding()
    .background(Palette.background)
}
