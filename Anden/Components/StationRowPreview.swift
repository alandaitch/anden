import SwiftUI
import CoreLocation

// Fila de estación con preview del próximo tren: nombre, línea, distancia y mini-countdown.
struct StationRowPreview: View {
    let station: Station
    var nextArrival: Arrival?
    var distance: CLLocationDistance?

    init(station: Station, nextArrival: Arrival?, distance: CLLocationDistance? = nil) {
        self.station = station
        self.nextArrival = nextArrival
        self.distance = distance
    }

    var body: some View {
        HStack(spacing: 12) {
            LineBadge(line: station.line, size: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(station.nombre)
                    .font(.anden(16, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(station.line.nombre)
                        .font(.anden(12, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                    if let distance {
                        Text("·")
                            .font(.anden(12, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                        Text(Formatting.distanceText(meters: distance))
                            .font(.anden(12, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
            }

            Spacer(minLength: 8)

            if let next = nextArrival {
                VStack(alignment: .trailing, spacing: 3) {
                    CountdownText(secondsUntil: next.secondsUntil, big: false)
                    Text("a \(next.destinationName)")
                        .font(.anden(11, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                }
            } else if !station.line.covered {
                Text("Sin datos")
                    .font(.anden(12, weight: .medium))
                    .foregroundStyle(Palette.noData)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.surface)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 10) {
        StationRowPreview(station: .boardPreview, nextArrival: .boardPreviewLive, distance: 320)
        StationRowPreview(station: .boardPreview, nextArrival: nil, distance: 1450)
    }
    .padding()
    .background(Palette.background)
}

extension Station {
    static var boardPreview: Station {
        Station(
            id: 332, nombre: "Retiro", lat: -34.591, lng: -58.374,
            linea: "Mitre", ramales: [], ramalesOperativos: [], gerenciaId: 5,
            visibleEnApp: true, enRamalPublico: true, tieneArribosHoy: true,
            distanciaObeliscoKm: 2.1, andenes: 3
        )
    }
}
