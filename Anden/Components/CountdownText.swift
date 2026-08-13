import SwiftUI

// Numeral héroe del countdown. Muestra "ahora"/"llegando" o el número de minutos grande + "min".
struct CountdownText: View {
    let secondsUntil: Int
    var big: Bool = true

    init(secondsUntil: Int, big: Bool = true) {
        self.secondsUntil = secondsUntil
        self.big = big
    }

    private var numberSize: CGFloat { big ? 44 : 26 }
    private var wordSize: CGFloat { big ? 24 : 16 }
    private var unitSize: CGFloat { big ? 15 : 12 }

    var body: some View {
        Group {
            if secondsUntil <= 30 {
                Text("ahora")
                    .font(.anden(wordSize, weight: .bold))
                    .foregroundStyle(Palette.onTime)
            } else if secondsUntil < 90 {
                Text("llegando")
                    .font(.anden(wordSize, weight: .bold))
                    .foregroundStyle(Palette.onTime)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(Formatting.minutesUntil(secondsUntil: secondsUntil))")
                        .font(.andenCountdown(numberSize))
                        .foregroundStyle(Palette.textPrimary)
                    Text("min")
                        .font(.anden(unitSize, weight: .semibold))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement()
        .accessibilityLabel(Formatting.etaText(secondsUntil: secondsUntil))
    }
}

#Preview {
    VStack(alignment: .trailing, spacing: 16) {
        CountdownText(secondsUntil: 15)
        CountdownText(secondsUntil: 60)
        CountdownText(secondsUntil: 240)
        CountdownText(secondsUntil: 1500)
        CountdownText(secondsUntil: 240, big: false)
    }
    .padding()
    .background(Palette.background)
}
