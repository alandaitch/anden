import SwiftUI

// Badge cuadrado redondeado con el color de la línea y su inicial en blanco.
struct LineBadge: View {
    let line: TrainLine
    var size: CGFloat = 28

    init(line: TrainLine, size: CGFloat = 28) {
        self.line = line
        self.size = size
    }

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(line.color)
            .overlay(
                Text(line.shortCode)
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
    HStack(spacing: 12) {
        ForEach(TrainLine.all) { line in
            LineBadge(line: line, size: 36)
        }
    }
    .padding()
    .background(Palette.background)
}
