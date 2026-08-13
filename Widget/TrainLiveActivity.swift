import ActivityKit
import WidgetKit
import SwiftUI

// Live Activity del tren seguido: pantalla bloqueada + Dynamic Island.
struct TrainLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrainActivityAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(Palette.background.opacity(0.92))
                .activitySystemActionForegroundColor(Color(hex: context.attributes.lineColorHex))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 7) {
                        WidgetLineBadge(
                            shortCode: context.attributes.lineShortCode,
                            colorHex: context.attributes.lineColorHex,
                            size: 30
                        )
                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.attributes.stationName)
                                .font(.anden(12, weight: .semibold))
                                .lineLimit(1)
                            Text(context.attributes.destinationName)
                                .font(.anden(11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        liveTimer(context, font: .andenCountdown(28), width: 82)
                        if let track = context.state.trackName {
                            Text("Andén \(track)")
                                .font(.anden(11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label(statusLabel(context), systemImage: statusIcon(context))
                            .font(.anden(12, weight: .semibold))
                            .foregroundStyle(delayColor(context))
                        Spacer()
                        Text("Llega")
                            .font(.anden(11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(hex: context.attributes.lineColorHex))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Text(context.attributes.lineShortCode)
                                .font(.anden(8, weight: .heavy))
                                .foregroundStyle(.white)
                                .minimumScaleFactor(0.6)
                        )
                }
            } compactTrailing: {
                liveTimer(context, font: .andenCountdown(14), width: 44)
                    .foregroundStyle(delayColor(context))
            } minimal: {
                Image(systemName: "tram.fill")
                    .foregroundStyle(Color(hex: context.attributes.lineColorHex))
            }
            .keylineTint(Color(hex: context.attributes.lineColorHex))
        }
    }

    // Countdown vivo que se auto-actualiza en pantalla.
    private func liveTimer(_ context: ActivityViewContext<TrainActivityAttributes>, font: Font, width: CGFloat) -> some View {
        Group {
            if context.state.isCancelled {
                Text("Cancelado")
                    .font(.anden(13, weight: .semibold))
                    .foregroundStyle(Palette.majorDelay)
            } else {
                Text(timerInterval: Date.now...max(context.state.eta, Date.now.addingTimeInterval(1)), countsDown: true)
                    .font(font)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: width, alignment: .trailing)
                    .lineLimit(1)
            }
        }
    }

    private func statusLabel(_ context: ActivityViewContext<TrainActivityAttributes>) -> String {
        context.state.isCancelled ? "Cancelado" : context.state.statusLabel
    }

    private func statusIcon(_ context: ActivityViewContext<TrainActivityAttributes>) -> String {
        if context.state.isCancelled { return "xmark.octagon.fill" }
        if context.state.statusLabel == "Sin datos" { return "questionmark.circle.fill" }
        if context.state.delaySeconds > 359 { return "exclamationmark.triangle.fill" }
        return "checkmark.circle.fill"
    }

    private func delayColor(_ context: ActivityViewContext<TrainActivityAttributes>) -> Color {
        if context.state.isCancelled { return Palette.majorDelay }
        if context.state.statusLabel == "Sin datos" { return Palette.noData }
        let d = context.state.delaySeconds
        if d <= 359 { return Palette.onTime }
        if d <= 718 { return Palette.minorDelay }
        return Palette.majorDelay
    }
}

// Vista de pantalla bloqueada de la Live Activity.
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<TrainActivityAttributes>

    private var delayColor: Color {
        if context.state.isCancelled { return Palette.majorDelay }
        if context.state.statusLabel == "Sin datos" { return Palette.noData }
        let d = context.state.delaySeconds
        if d <= 359 { return Palette.onTime }
        if d <= 718 { return Palette.minorDelay }
        return Palette.majorDelay
    }

    var body: some View {
        HStack(spacing: 12) {
            WidgetLineBadge(
                shortCode: context.attributes.lineShortCode,
                colorHex: context.attributes.lineColorHex,
                size: 44
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(context.attributes.stationName)
                    .font(.anden(13, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.anden(11, weight: .bold))
                        .foregroundStyle(Palette.textSecondary)
                    Text(context.attributes.destinationName)
                        .font(.anden(17, weight: .bold))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                HStack(spacing: 6) {
                    Text(context.state.isCancelled ? "Cancelado" : context.state.statusLabel)
                        .font(.anden(12, weight: .semibold))
                        .foregroundStyle(delayColor)
                    if let track = context.state.trackName {
                        Text("· Andén \(track)")
                            .font(.anden(12, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 1) {
                if context.state.isCancelled {
                    Image(systemName: "xmark.octagon.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Palette.majorDelay)
                } else {
                    Text(timerInterval: Date.now...max(context.state.eta, Date.now.addingTimeInterval(1)), countsDown: true)
                        .font(.andenCountdown(34))
                        .monospacedDigit()
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(minWidth: 92, alignment: .trailing)
                    Text("min")
                        .font(.anden(11, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        }
        .padding(14)
    }
}
