import SwiftUI

// Badge cuadrado redondeado con el color oficial de la línea de subte y su letra.
// Elige texto negro o blanco según la luminancia (la línea H amarilla necesita negro).
struct SubteBadge: View {
    let line: SubteLine
    var size: CGFloat = 32

    init(line: SubteLine, size: CGFloat = 32) {
        self.line = line
        self.size = size
    }

    private var textColor: Color {
        SubteBadge.isLight(hex: line.colorHex) ? .black : .white
    }

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(line.color)
            .overlay(
                Text(line.letra)
                    .font(.system(size: size * 0.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(textColor)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, 1)
            )
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
            )
            .accessibilityElement()
            .accessibilityLabel(line.nombre)
    }

    // Luminancia relativa del color para decidir el color del texto.
    static func isLight(hex: String) -> Bool {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return false }
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        let lum = 0.299 * r + 0.587 * g + 0.114 * b
        return lum > 0.6
    }
}

#Preview {
    HStack(spacing: 12) {
        ForEach(SubteLine.all) { line in
            SubteBadge(line: line, size: 40)
        }
    }
    .padding()
    .background(Palette.background)
}
