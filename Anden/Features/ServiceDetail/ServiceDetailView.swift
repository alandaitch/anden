import SwiftUI
import MapKit
import CoreLocation

// Detalle de un servicio: header, mapa en vivo con el tren moviéndose,
// timeline del recorrido y botón de Live Activity.
struct ServiceDetailView: View {
    @State private var arrival: Arrival
    @State private var camera: MapCameraPosition = .automatic
    @State private var trainCoordinate: CLLocationCoordinate2D?
    @State private var activitiesEnabled = false
    @State private var loadFailed = false
    @State private var didFitCamera = false
    @State private var followTrigger = 0
    @State private var pulse = false

    init(arrival: Arrival) {
        _arrival = State(initialValue: arrival)
        _trainCoordinate = State(initialValue: arrival.trainLocation)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                mapCard
                followButton
                timelineCard
            }
            .padding(16)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle(arrival.destinationName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            activitiesEnabled = LiveActivityController.shared.activitiesEnabled
            fitCameraIfNeeded()
            pulse = true
        }
        .task {
            await pollLoop()
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                LineBadge(line: arrival.line, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(arrival.destinationName)
                        .font(.anden(22, weight: .bold))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(arrival.ramalName)
                        .font(.anden(14, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                LiveDot(active: trainCoordinate != nil)
            }

            HStack(spacing: 10) {
                DelayPill(arrival.delay)
                if let state = arrival.stateName, !state.isEmpty {
                    Text(state)
                        .font(.anden(13, weight: .semibold))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Palette.surface, in: Capsule())
                }
                Spacer(minLength: 0)
            }

            Divider().overlay(Palette.textSecondary.opacity(0.15))

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(arrival.isCancelled ? "Servicio cancelado" : "Llega en")
                        .font(.anden(13, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                    if let track = arrival.trackName {
                        Text("Andén \(track)")
                            .font(.anden(13, weight: .semibold))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                if !arrival.isCancelled {
                    CountdownText(secondsUntil: arrival.secondsUntil, big: true)
                }
            }

            if loadFailed {
                Label("No pude actualizar la posición. Reintento solo.", systemImage: "wifi.exclamationmark")
                    .font(.anden(12, weight: .medium))
                    .foregroundStyle(Palette.minorDelay)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .andenCard()
    }

    // MARK: Mapa

    private var mapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(
                title: "En el mapa",
                subtitle: trainCoordinate == nil ? "Sin GPS del tren ahora" : "Posición en vivo"
            )
            Map(position: $camera) {
                if routeCoordinates.count >= 2 {
                    MapPolyline(coordinates: routeCoordinates)
                        .stroke(arrival.line.color, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }
                ForEach(arrival.route) { stop in
                    if let coord = coordinate(for: stop) {
                        Annotation("", coordinate: coord, anchor: .center) {
                            stopDot(stop)
                        }
                    }
                }
                if let tc = trainCoordinate {
                    Annotation("", coordinate: tc, anchor: .center) {
                        trainMarker
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if trainCoordinate == nil {
                Text("Este servicio no está reportando GPS. Te muestro el recorrido y los horarios.")
                    .font(.anden(12))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .andenCard()
    }

    private var trainMarker: some View {
        ZStack {
            Circle()
                .fill(arrival.line.color.opacity(0.28))
                .frame(width: 44, height: 44)
                .scaleEffect(pulse ? 1.15 : 0.85)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
            Circle()
                .fill(arrival.line.color)
                .frame(width: 30, height: 30)
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
            Image(systemName: "tram.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func stopDot(_ stop: RouteStop) -> some View {
        let isNext = stop.id == nextStopId
        return Circle()
            .fill(stop.hasPassed ? Palette.textSecondary.opacity(0.5) : arrival.line.color)
            .frame(width: isNext ? 14 : 10, height: isNext ? 14 : 10)
            .overlay(Circle().stroke(.white, lineWidth: isNext ? 2 : 1))
            .opacity(stop.hasPassed ? 0.6 : 1)
    }

    // MARK: Botón de Live Activity

    @ViewBuilder
    private var followButton: some View {
        if arrival.serviceId != nil && activitiesEnabled {
            let following = LiveActivityController.shared.isFollowing(arrival.serviceId)
            Button {
                if following {
                    LiveActivityController.shared.end()
                } else {
                    LiveActivityController.shared.start(for: arrival)
                }
                followTrigger += 1
            } label: {
                Label(
                    following ? "Dejar de seguir" : "Seguir en pantalla bloqueada",
                    systemImage: following ? "bell.slash.fill" : "bell.badge.fill"
                )
                .font(.anden(16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(following ? Palette.surface : arrival.line.color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(following ? Palette.textPrimary : .white)
            }
            .sensoryFeedback(.success, trigger: followTrigger)
        } else if arrival.serviceId == nil {
            Text("El seguimiento en pantalla bloqueada está disponible solo en modo vivo.")
                .font(.anden(12))
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Timeline del recorrido

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeaderView(title: "Recorrido", subtitle: recorridoSubtitle)
                .padding(.bottom, 8)
            if arrival.route.isEmpty {
                Text("Sin recorrido disponible para este servicio.")
                    .font(.anden(13))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(arrival.route.enumerated()), id: \.element.id) { index, stop in
                    RouteTimelineRow(
                        stop: stop,
                        lineColor: arrival.line.color,
                        isFirst: index == 0,
                        isLast: index == arrival.route.count - 1,
                        isNext: stop.id == nextStopId
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .andenCard()
    }

    private var recorridoSubtitle: String? {
        guard !arrival.route.isEmpty else { return nil }
        let restantes = arrival.route.filter { !$0.hasPassed }.count
        return "\(restantes) paradas por delante"
    }

    // MARK: Datos derivados

    private var routeCoordinates: [CLLocationCoordinate2D] {
        arrival.route.compactMap { coordinate(for: $0) }
    }

    private func coordinate(for stop: RouteStop) -> CLLocationCoordinate2D? {
        StationCatalog.shared.station(id: stop.stationId)?.coordinate
    }

    private var nextStopId: Int? {
        arrival.route.first(where: { !$0.hasPassed })?.id
    }

    // Estación para re-consultar arribos: la próxima parada, o la última.
    private var pollStationId: Int? {
        if let next = arrival.route.first(where: { !$0.hasPassed }) { return next.stationId }
        if let last = arrival.route.last { return last.stationId }
        return StationCatalog.shared.search(arrival.originName).first?.id
    }

    // MARK: Cámara

    private func fitCameraIfNeeded() {
        guard !didFitCamera else { return }
        var coords = routeCoordinates
        if let tc = trainCoordinate { coords.append(tc) }
        guard !coords.isEmpty else { return }
        let lats = coords.map(\.latitude)
        let lngs = coords.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLng = lngs.min(), let maxLng = lngs.max() else { return }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.02),
            longitudeDelta: max((maxLng - minLng) * 1.4, 0.02)
        )
        camera = .region(MKCoordinateRegion(center: center, span: span))
        didFitCamera = true
    }

    // MARK: Refresco cada 20s

    private func pollLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            if Task.isCancelled { break }
            await refreshOnce()
        }
    }

    private func refreshOnce() async {
        guard let serviceId = arrival.serviceId, let target = pollStationId else { return }
        do {
            let list = try await SofseClient.shared.arrivals(stationId: target, limit: 12)
            if let updated = list.first(where: { $0.serviceId == serviceId }) {
                withAnimation(.linear(duration: 0.9)) {
                    arrival = updated
                    if let loc = updated.trainLocation {
                        trainCoordinate = loc
                    }
                }
                loadFailed = false
                LiveActivityController.shared.update(for: updated)
            }
        } catch {
            loadFailed = true
        }
    }
}

// Fila del timeline vertical de una parada.
private struct RouteTimelineRow: View {
    let stop: RouteStop
    let lineColor: Color
    let isFirst: Bool
    let isLast: Bool
    let isNext: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            connector
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var connector: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isFirst ? .clear : segmentColor)
                .frame(width: 3, height: 10)
            Circle()
                .fill(stop.hasPassed ? Palette.textSecondary.opacity(0.5) : lineColor)
                .frame(width: isNext ? 15 : 11, height: isNext ? 15 : 11)
                .overlay(Circle().stroke(Palette.elevated, lineWidth: 2))
            Rectangle()
                .fill(isLast ? .clear : segmentColor)
                .frame(width: 3)
                .frame(maxHeight: .infinity)
        }
        .frame(width: 15)
    }

    private var segmentColor: Color {
        stop.hasPassed ? Palette.textSecondary.opacity(0.35) : lineColor.opacity(0.55)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(stop.name)
                .font(.anden(15, weight: isNext ? .bold : .semibold))
                .foregroundStyle(stop.hasPassed ? Palette.textSecondary : Palette.textPrimary)
                .lineLimit(1)
            HStack(spacing: 8) {
                Text(Formatting.clock(stop.scheduled))
                    .font(.anden(13, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                if let estimated = stop.estimated, stop.scheduled != estimated {
                    Text("est. \(Formatting.clock(estimated))")
                        .font(.anden(13, weight: .semibold))
                        .foregroundStyle(lineColor)
                }
                if let track = stop.trackName {
                    Text("· And. \(track)")
                        .font(.anden(12, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        }
        .padding(.bottom, 14)
        .opacity(stop.hasPassed ? 0.5 : 1)
    }
}
