import Foundation
import ActivityKit

// Controla la Live Activity de "seguir un servicio" en pantalla bloqueada.
// Singleton @MainActor. Usa TrainActivityAttributes del core.
@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()

    private var currentActivity: Activity<TrainActivityAttributes>?

    private init() {
        // Reconectá con una actividad viva tras relanzar la app.
        currentActivity = Activity<TrainActivityAttributes>.activities.first
    }

    // ¿El sistema permite Live Activities?
    var activitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // ¿Estoy siguiendo este servicio ahora?
    func isFollowing(_ serviceId: String?) -> Bool {
        guard let serviceId else { return false }
        return AppSettings.shared.seguirServicioId == serviceId
    }

    // Arranca la actividad para un arribo. Requiere serviceId (modo vivo).
    func start(for arrival: Arrival) {
        guard activitiesEnabled else { return }
        guard let serviceId = arrival.serviceId else { return }

        // Cerrá cualquier actividad previa antes de abrir la nueva.
        endAll()

        let attributes = TrainActivityAttributes(
            stationName: arrival.originName,
            destinationName: arrival.destinationName,
            lineColorHex: arrival.line.colorHex,
            lineShortCode: arrival.line.shortCode
        )
        let state = Self.contentState(for: arrival)
        let content = ActivityContent(state: state, staleDate: state.eta)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            currentActivity = activity
            AppSettings.shared.seguirServicioId = serviceId
        } catch {
            // Falló el pedido de actividad. Dejá el estado limpio.
            currentActivity = nil
        }
    }

    // Actualiza la posición y el ETA de la actividad viva.
    func update(for arrival: Arrival) {
        guard let activity = currentActivity else { return }
        let state = Self.contentState(for: arrival)
        let content = ActivityContent(state: state, staleDate: state.eta)
        Task {
            await activity.update(content)
        }
    }

    // Termina la actividad y limpia el ajuste.
    func end() {
        AppSettings.shared.seguirServicioId = nil
        endAll()
    }

    private func endAll() {
        let activities = Activity<TrainActivityAttributes>.activities
        currentActivity = nil
        for activity in activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    // Construye el ContentState desde un arribo.
    private static func contentState(for arrival: Arrival) -> TrainActivityAttributes.ContentState {
        let eta = arrival.estimated
            ?? arrival.scheduled
            ?? Date().addingTimeInterval(TimeInterval(arrival.secondsUntil))
        return TrainActivityAttributes.ContentState(
            eta: eta,
            delaySeconds: arrival.delay.delaySeconds ?? 0,
            statusLabel: arrival.delay.label,
            trackName: arrival.trackName,
            isCancelled: arrival.isCancelled
        )
    }
}
