import SwiftUI
import MapKit

// Capa opcional de estaciones EcoBici para montar dentro de un Map(position:) existente.
// No mantiene estado propio: la vista dueña del mapa guarda `[EcobiciStation]` en su @State,
// lo llena con `EcobiciMapLayer.fetchStations()` y pinta las anotaciones con
// `EcobiciMapLayer.annotations(stations:)` dentro del @MapContentBuilder del Map.
enum EcobiciMapLayer {
    // Trae las estaciones EcoBici en vivo. Deja que el caller decida cuándo pedirlas
    // (ej. .task al activar el toggle) y cómo degradar el error.
    static func fetchStations() async throws -> [EcobiciStation] {
        try await BAClient.shared.ecobiciStations()
    }

    // Contenido de mapa: una Annotation con pin de bici por estación.
    // Uso típico dentro de un Map existente:
    //   Map(position: $camera) {
    //       ForEach(trains) { ... }
    //       if showEcobici {
    //           EcobiciMapLayer.annotations(stations: ecobiciStations) { selectedStation = $0 }
    //       }
    //   }
    @MainActor
    @MapContentBuilder
    static func annotations(
        stations: [EcobiciStation],
        onSelect: @escaping (EcobiciStation) -> Void = { _ in }
    ) -> some MapContent {
        ForEach(stations) { station in
            Annotation(station.displayName, coordinate: station.coordinate, anchor: .center) {
                EcobiciMapPin(station: station)
                    .frame(width: 34, height: 34)
                    .contentShape(Circle())
                    .onTapGesture { onSelect(station) }
            }
        }
    }
}

// Pin de una estación EcoBici para un Map. Color según disponibilidad de bicis.
struct EcobiciMapPin: View {
    let station: EcobiciStation
    var size: CGFloat = 26

    private var availability: Double {
        guard station.capacity > 0 else { return 0 }
        return Double(station.bikesTotal) / Double(station.capacity)
    }

    // Fuera de servicio = gris. Sin bicis = rojo. Poca disponibilidad = ámbar. Resto = verde.
    private var color: Color {
        guard station.status == "IN_SERVICE" else { return Palette.noData }
        if station.bikesTotal == 0 { return Palette.majorDelay }
        if availability < 0.25 { return Palette.minorDelay }
        return Palette.onTime
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            Image(systemName: "bicycle")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white)
        }
        .accessibilityElement()
        .accessibilityLabel("\(station.displayName): \(station.bikesTotal) bicis disponibles")
    }
}

#Preview {
    HStack(spacing: 16) {
        EcobiciMapPin(station: EcobiciStation(
            id: "1", name: "002 - Retiro I", lat: 0, lng: 0, capacity: 20,
            bikesMechanical: 10, bikesEbike: 2, bikesTotal: 12, docksAvailable: 8,
            status: "IN_SERVICE", lastReported: Date()
        ))
        EcobiciMapPin(station: EcobiciStation(
            id: "2", name: "010 - Plaza Francia", lat: 0, lng: 0, capacity: 20,
            bikesMechanical: 0, bikesEbike: 0, bikesTotal: 0, docksAvailable: 20,
            status: "IN_SERVICE", lastReported: Date()
        ))
        EcobiciMapPin(station: EcobiciStation(
            id: "3", name: "015 - Constitución", lat: 0, lng: 0, capacity: 20,
            bikesMechanical: 1, bikesEbike: 0, bikesTotal: 1, docksAvailable: 19,
            status: "IN_SERVICE", lastReported: Date()
        ))
        EcobiciMapPin(station: EcobiciStation(
            id: "4", name: "020 fuera de servicio", lat: 0, lng: 0, capacity: 20,
            bikesMechanical: 0, bikesEbike: 0, bikesTotal: 0, docksAvailable: 0,
            status: "NOT_IN_SERVICE", lastReported: Date()
        ))
    }
    .padding()
    .background(Palette.background)
}
