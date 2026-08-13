import SwiftUI

// Cápsula con color semántico y label de demora.
struct DelayPill: View {
    let status: DelayStatus
    var compact: Bool = false

    init(_ status: DelayStatus, compact: Bool = false) {
        self.status = status
        self.compact = compact
    }

    private var icon: String? {
        switch status {
        case .onTime:    return "checkmark.circle.fill"
        case .early:     return "hare.fill"
        case .minor:     return "clock.fill"
        case .major:     return "exclamationmark.triangle.fill"
        case .cancelled: return "xmark.octagon.fill"
        case .noData:    return nil
        }
    }

    var body: some View {
        let color = status.color
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: compact ? 9 : 10, weight: .bold))
            }
            Text(compact ? status.shortLabel : status.label)
                .font(.anden(compact ? 11 : 12, weight: .bold))
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 3 : 4)
        .background(
            Capsule(style: .continuous).fill(color.opacity(0.16))
        )
        .overlay(
            Capsule(style: .continuous).strokeBorder(color.opacity(0.28), lineWidth: 0.5)
        )
        .accessibilityElement()
        .accessibilityLabel(status.label)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        DelayPill(.onTime)
        DelayPill(.early(seconds: 120))
        DelayPill(.minor(seconds: 240))
        DelayPill(.major(seconds: 900))
        DelayPill(.noData)
        DelayPill(.cancelled)
        DelayPill(.major(seconds: 900), compact: true)
    }
    .padding()
    .background(Palette.background)
}
