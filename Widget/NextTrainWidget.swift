import WidgetKit
import SwiftUI

// MARK: - Timeline

struct NextTrainEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct NextTrainProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextTrainEntry {
        NextTrainEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (NextTrainEntry) -> Void) {
        if context.isPreview {
            completion(NextTrainEntry(date: .now, snapshot: .sample))
            return
        }
        completion(NextTrainEntry(date: .now, snapshot: WidgetSnapshot.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextTrainEntry>) -> Void) {
        Task {
            var snapshot = WidgetSnapshot.read()

            // Si el snapshot está viejo (>2 min), intentamos refrescar directo.
            if let current = snapshot, current.age > 120 {
                if let fresh = await WidgetSnapshot.refreshInWidget(previous: current) {
                    snapshot = fresh
                }
            }

            let entry = NextTrainEntry(date: .now, snapshot: snapshot)
            // Recargamos en 1 min: los countdown se auto-actualizan solos mientras tanto.
            let next = Date().addingTimeInterval(60)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

// MARK: - Widget

struct NextTrainWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextTrainWidget", provider: NextTrainProvider()) { entry in
            NextTrainEntryView(entry: entry)
        }
        .configurationDisplayName("Próximo arribo")
        .description("El próximo arribo en tu parada favorita (tren, subte o colectivo).")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline
        ])
    }
}

// MARK: - Root view

struct NextTrainEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextTrainEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                content(for: snapshot)
            } else {
                EmptyWidgetView(family: family)
            }
        }
        .widgetBackground(family: family)
    }

    @ViewBuilder
    private func content(for snapshot: WidgetSnapshot) -> some View {
        if snapshot.arrivals.isEmpty {
            NoTrainsWidgetView(snapshot: snapshot, family: family)
        } else {
            switch family {
            case .systemSmall:        SmallWidgetView(snapshot: snapshot)
            case .systemMedium:       MediumWidgetView(snapshot: snapshot)
            case .accessoryRectangular: RectangularWidgetView(snapshot: snapshot)
            case .accessoryCircular:  CircularWidgetView(snapshot: snapshot)
            case .accessoryInline:    InlineWidgetView(snapshot: snapshot)
            default:                  SmallWidgetView(snapshot: snapshot)
            }
        }
    }
}

// MARK: - Shared bits

// Badge de línea local (el widget no puede usar el componente LineBadge de la app).
struct WidgetLineBadge: View {
    let shortCode: String
    let colorHex: String
    var size: CGFloat = 30

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(Color(hex: colorHex))
            .frame(width: size, height: size)
            .overlay(
                Group {
                    if shortCode.isEmpty {
                        // Colectivo: la parada no tiene una única línea.
                        Image(systemName: "bus.fill")
                            .font(.system(size: size * 0.5, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Text(shortCode)
                            .font(.anden(size * 0.42, weight: .heavy))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .padding(.horizontal, 1)
                    }
                }
            )
    }
}

// Punto "en vivo" que pulsa.
struct WidgetLiveDot: View {
    var color: Color = Palette.onTime
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
    }
}

private extension MiniArrival {
    var delayColor: Color {
        if statusLabel == "Cancelado" { return Palette.majorDelay }
        if statusLabel == "Sin datos" { return Palette.noData }
        if delaySeconds <= -60 { return Palette.onTime }
        if delaySeconds <= 359 { return Palette.onTime }
        if delaySeconds <= 718 { return Palette.minorDelay }
        return Palette.majorDelay
    }
}

// MARK: - systemSmall

struct SmallWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        let next = snapshot.arrivals[0]
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                WidgetLineBadge(shortCode: snapshot.lineShortCode, colorHex: snapshot.lineColorHex, size: 26)
                Text(snapshot.stationName)
                    .font(.anden(13, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                WidgetLiveDot(color: next.delayColor)
            }

            Spacer(minLength: 4)

            Text(next.eta, style: .timer)
                .font(.andenCountdown(40))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())

            HStack(spacing: 4) {
                Image(systemName: "arrow.right")
                    .font(.anden(10, weight: .bold))
                    .foregroundStyle(Palette.textSecondary)
                Text(next.destino)
                    .font(.anden(13, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                Text(next.statusLabel)
                    .font(.anden(11, weight: .semibold))
                    .foregroundStyle(next.delayColor)
                if let track = next.trackName {
                    Text("And. \(track)")
                        .font(.anden(11, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        }
    }
}

// MARK: - systemMedium

struct MediumWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                WidgetLineBadge(shortCode: snapshot.lineShortCode, colorHex: snapshot.lineColorHex, size: 28)
                Text(snapshot.stationName)
                    .font(.anden(15, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                WidgetLiveDot(color: snapshot.arrivals[0].delayColor)
                Text("EN VIVO")
                    .font(.anden(9, weight: .heavy))
                    .foregroundStyle(Palette.textSecondary)
            }

            VStack(spacing: 6) {
                ForEach(Array(snapshot.arrivals.prefix(3))) { arrival in
                    MediumArrivalRow(arrival: arrival)
                    if arrival.id != snapshot.arrivals.prefix(3).last?.id {
                        Divider().overlay(Palette.textSecondary.opacity(0.15))
                    }
                }
            }
        }
    }
}

private struct MediumArrivalRow: View {
    let arrival: MiniArrival

    var body: some View {
        HStack(spacing: 8) {
            Text(arrival.destino)
                .font(.anden(14, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 4)

            Text(arrival.statusLabel)
                .font(.anden(11, weight: .semibold))
                .foregroundStyle(arrival.delayColor)

            Text(arrival.eta, style: .timer)
                .font(.andenCountdown(17))
                .foregroundStyle(Palette.textPrimary)
                .frame(minWidth: 52, alignment: .trailing)
                .lineLimit(1)
        }
    }
}

// MARK: - accessoryRectangular (lock screen)

struct RectangularWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        let next = snapshot.arrivals[0]
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: snapshot.modeIcon)
                    .font(.system(size: 11, weight: .bold))
                Text(snapshot.lineShortCode.isEmpty ? snapshot.stationName : "\(snapshot.lineShortCode) · \(snapshot.stationName)")
                    .font(.anden(12, weight: .semibold))
                    .lineLimit(1)
            }
            HStack(spacing: 4) {
                Text(next.destino)
                    .font(.anden(13, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(next.eta, style: .timer)
                    .font(.andenCountdown(14))
                    .lineLimit(1)
            }
            Text(next.statusLabel)
                .font(.anden(11, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .widgetAccentable()
    }
}

// MARK: - accessoryCircular (lock screen)

struct CircularWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        let next = snapshot.arrivals[0]
        VStack(spacing: 0) {
            if snapshot.lineShortCode.isEmpty {
                Image(systemName: snapshot.modeIcon)
                    .font(.system(size: 11, weight: .bold))
            } else {
                Text(snapshot.lineShortCode)
                    .font(.anden(11, weight: .heavy))
            }
            Text(next.eta, style: .timer)
                .font(.andenCountdown(13))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .widgetAccentable()
    }
}

// MARK: - accessoryInline (lock screen)

struct InlineWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        let next = snapshot.arrivals[0]
        HStack(spacing: 3) {
            Image(systemName: snapshot.modeIcon)
            Text("\(next.destino) ")
            Text(next.eta, style: .relative)
        }
    }
}

// MARK: - Estados vacíos

struct EmptyWidgetView: View {
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryInline:
            HStack(spacing: 3) {
                Image(systemName: "tram.fill")
                Text("Elegí un favorito")
            }
        case .accessoryCircular:
            VStack(spacing: 1) {
                Image(systemName: "tram.fill").font(.system(size: 15, weight: .bold))
                Text("Andén").font(.anden(9, weight: .semibold))
            }
            .widgetAccentable()
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("Andén", systemImage: "tram.fill")
                    .font(.anden(13, weight: .semibold))
                Text("Elegí un favorito en la app")
                    .font(.anden(11))
                    .foregroundStyle(.secondary)
            }
            .widgetAccentable()
        default:
            VStack(spacing: 8) {
                Image(systemName: "tram.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Palette.brand)
                Text("Elegí un favorito en Andén")
                    .font(.anden(13, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(8)
        }
    }
}

struct NoTrainsWidgetView: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryInline:
            HStack(spacing: 3) {
                Image(systemName: snapshot.modeIcon)
                Text("Sin arribos próximos")
            }
        case .accessoryCircular:
            VStack(spacing: 1) {
                Image(systemName: snapshot.modeIcon).font(.system(size: 12, weight: .bold))
                Image(systemName: "moon.zzz.fill").font(.system(size: 12))
            }
            .widgetAccentable()
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.lineShortCode.isEmpty ? snapshot.stationName : "\(snapshot.lineShortCode) · \(snapshot.stationName)")
                    .font(.anden(12, weight: .semibold))
                    .lineLimit(1)
                Text("Sin arribos próximos")
                    .font(.anden(11))
                    .foregroundStyle(.secondary)
            }
            .widgetAccentable()
        default:
            VStack(spacing: 8) {
                HStack(spacing: 7) {
                    WidgetLineBadge(shortCode: snapshot.lineShortCode, colorHex: snapshot.lineColorHex, size: 26)
                    Text(snapshot.stationName)
                        .font(.anden(13, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Palette.textSecondary)
                Text("Sin arribos próximos")
                    .font(.anden(12, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(8)
        }
    }
}

// MARK: - Fondo del contenedor (iOS 17)

private extension View {
    @ViewBuilder
    func widgetBackground(family: WidgetFamily) -> some View {
        switch family {
        case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge:
            self.containerBackground(for: .widget) { Palette.background }
        default:
            // Familias accessory: fondo del sistema (vibrante en lock screen).
            self.containerBackground(for: .widget) { Color.clear }
        }
    }
}
