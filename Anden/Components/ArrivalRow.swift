import SwiftUI

// Fila rica de un arribo: destino, badge de línea, andén, countdown, demora y punto en vivo.
struct ArrivalRow: View {
    let arrival: Arrival

    // Hay señal en vivo si viene GPS del tren o una hora estimada.
    private var isLive: Bool {
        arrival.trainLocation != nil || arrival.estimated != nil
    }

    var body: some View {
        HStack(spacing: 12) {
            LineBadge(line: arrival.line, size: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(arrival.destinationName)
                        .font(.anden(17, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                    if isLive {
                        LiveDot(active: true, color: Palette.onTime, size: 6)
                    }
                }

                HStack(spacing: 10) {
                    if !arrival.ramalName.isEmpty {
                        Label(arrival.ramalName, systemImage: "arrow.triangle.branch")
                            .font(.anden(12, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(1)
                    }
                    if let track = arrival.trackName, !track.isEmpty {
                        Label("And. \(track)", systemImage: "figure.walk")
                            .font(.anden(12, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                CountdownText(secondsUntil: arrival.secondsUntil, big: false)
                DelayPill(arrival.delay, compact: true)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.surface)
        )
        .overlay(alignment: .leading) {
            // Barra de acento con el color de la línea.
            RoundedRectangle(cornerRadius: 3)
                .fill(arrival.line.color)
                .frame(width: 4)
                .padding(.vertical, 12)
                .padding(.leading, 2)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(arrival.line.nombre) a \(arrival.destinationName), \(Formatting.etaText(secondsUntil: arrival.secondsUntil)), \(arrival.delay.label)")
    }
}

#Preview {
    VStack(spacing: 10) {
        ArrivalRow(arrival: .boardPreviewLive)
        ArrivalRow(arrival: .boardPreviewScheduled)
    }
    .padding()
    .background(Palette.background)
}

extension Arrival {
    static var boardPreviewLive: Arrival {
        Arrival(
            id: "p1", serviceId: "abc", lineId: 5, line: .line(id: 5),
            ramalName: "Tigre", destinationName: "Tigre", originName: "Retiro",
            trackName: "2", scheduled: Date().addingTimeInterval(300), estimated: Date().addingTimeInterval(420),
            secondsUntil: 420, delay: .minor(seconds: 120),
            trainLocation: .init(latitude: -34.5, longitude: -58.5),
            equipmentName: "CSR", isElectric: true, isCancelled: false,
            direction: 1, stateName: "En Andén", route: []
        )
    }
    static var boardPreviewScheduled: Arrival {
        Arrival(
            id: "p2", serviceId: nil, lineId: 11, line: .line(id: 11),
            ramalName: "La Plata", destinationName: "La Plata", originName: "Constitución",
            trackName: nil, scheduled: Date().addingTimeInterval(900), estimated: nil,
            secondsUntil: 900, delay: .noData,
            trainLocation: nil, equipmentName: nil, isElectric: true, isCancelled: false,
            direction: 1, stateName: nil, route: []
        )
    }
}
