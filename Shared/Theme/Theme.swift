import SwiftUI

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v & 0xFF0000) >> 16) / 255
        let g = Double((v & 0x00FF00) >> 8) / 255
        let b = Double(v & 0x0000FF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

// Paleta del PLAN. Colores de línea, semánticos y fondos.
enum Palette {
    // Semánticos de demora
    static let onTime = Color(hex: "#22C55E")
    static let minorDelay = Color(hex: "#F59E0B")
    static let majorDelay = Color(hex: "#EF4444")
    static let noData = Color(hex: "#8A94A6")

    // Marca (chrome)
    static let brand = Color(hex: "#242C4F")

    // Fondos dinámicos (oscuro OLED / claro)
    static let background = dynamic(light: "#EEF1F5", dark: "#0A0C10")
    static let surface = dynamic(light: "#FFFFFF", dark: "#151A22")
    static let elevated = dynamic(light: "#FFFFFF", dark: "#1E242E")

    // Texto
    static let textPrimary = dynamic(light: "#0A0C10", dark: "#F5F7FA")
    static let textSecondary = dynamic(light: "#5B6472", dark: "#9AA4B2")

    static func dynamic(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
        })
    }
}

enum Theme {
    static func color(line: TrainLine) -> Color { line.color }
    static func color(delay: DelayStatus) -> Color { delay.color }
}

extension Color {
    static func line(_ line: TrainLine) -> Color { line.color }
    static func delay(_ status: DelayStatus) -> Color { status.color }
}

// Tipografía redondeada.
extension Font {
    static func anden(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // Numeral grande del countdown, con dígitos monoespaciados.
    static func andenCountdown(_ size: CGFloat = 56) -> Font {
        .system(size: size, weight: .bold, design: .rounded).monospacedDigit()
    }
}

// Tarjeta estándar de la app.
struct AndenCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Palette.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 4)
    }
}

extension View {
    func andenCard() -> some View { modifier(AndenCard()) }
}

// Badge de identidad de línea (color + inicial).
struct LineBadgeStyle {
    let line: TrainLine
    var background: Color { line.color }
    var foreground: Color { .white }
    var code: String { line.shortCode }
}
