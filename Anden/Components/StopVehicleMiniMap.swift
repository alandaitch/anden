import SwiftUI
import MapKit

// Mini-mapa de "tu parada + el vehículo viniendo". Solo visual (no interactivo).
// Muestra la parada (señal), tu ubicación, el recorrido en punteado y, si hay GPS,
// el coche que se acerca; se auto-encuadra a parada + coche.
struct StopVehicleMiniMap: View {
    let stop: CLLocationCoordinate2D
    let vehicle: CLLocationCoordinate2D?
    var route: [CLLocationCoordinate2D] = []
    var tint: Color = Palette.brand
    var vehicleIcon: String = "tram.fill"
    var stopIcon: String = "tram.fill"
    var height: CGFloat = 160

    @State private var camera: MapCameraPosition = .automatic
    @State private var pulse = false

    var body: some View {
        Map(position: $camera, interactionModes: []) {
            if route.count > 1 {
                MapPolyline(coordinates: route)
                    .stroke(tint.opacity(0.65),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [1, 7]))
            }
            Annotation("Tu parada", coordinate: stop) { stopPin }
                .annotationTitles(.hidden)
            if let vehicle {
                Annotation("En camino", coordinate: vehicle) { vehiclePin }
                    .annotationTitles(.hidden)
            }
            UserAnnotation()
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Palette.textSecondary.opacity(0.12), lineWidth: 1)
        )
        .onAppear {
            fit()
            pulse = true
        }
        .onChange(of: vehicleKey) { _, _ in fit() }
    }

    private var vehicleKey: String {
        vehicle.map { "\($0.latitude),\($0.longitude)" } ?? "none"
    }

    private func fit() {
        withAnimation(.easeInOut(duration: 0.6)) {
            camera = .region(region())
        }
    }

    private func region() -> MKCoordinateRegion {
        guard let v = vehicle else {
            return MKCoordinateRegion(center: stop, span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008))
        }
        let minLat = min(stop.latitude, v.latitude), maxLat = max(stop.latitude, v.latitude)
        let minLon = min(stop.longitude, v.longitude), maxLon = max(stop.longitude, v.longitude)
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: Swift.max(0.005, (maxLat - minLat) * 1.7),
            longitudeDelta: Swift.max(0.005, (maxLon - minLon) * 1.7)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    // Señal de parada: cartelito blanco con el glifo del modo (más lindo que un círculo).
    private var stopPin: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(.white)
            .frame(width: 28, height: 28)
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(tint, lineWidth: 2.5)
            )
            .overlay(
                Image(systemName: stopIcon)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(tint)
            )
            .shadow(color: .black.opacity(0.22), radius: 2.5, y: 1)
    }

    private var vehiclePin: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.28))
                .frame(width: 34, height: 34)
                .scaleEffect(pulse ? 1.25 : 0.85)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
            Circle()
                .fill(tint)
                .frame(width: 22, height: 22)
                .overlay(
                    Image(systemName: vehicleIcon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                )
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
        }
    }
}
