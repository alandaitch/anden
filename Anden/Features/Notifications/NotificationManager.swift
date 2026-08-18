import Foundation
import UserNotifications
import BackgroundTasks

// Notificaciones de demora, mejor esfuerzo.
// Sin servidor propio no hay push en tiempo real.
// iOS decide cuándo corre la tarea de background. No hay horario garantizado.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    static let refreshTaskIdentifier = "com.alandaitch.anden.refresh"
    private static let minimumInterval: TimeInterval = 15 * 60
    private static let notifiedCacheKey = "notifications.notifiedArrivals.v1"

    private let defaults: UserDefaults
    private var hasRegisteredBackgroundTasks = false
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? (UserDefaults(suiteName: "group.com.alandaitch.anden") ?? .standard)
    }

    // MARK: - Permisos

    // Pide autorización de notificaciones. Devuelve true si el usuario acepta.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            await refreshAuthorizationStatus()
            return false
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - Background tasks

    // Registrá una sola vez, apenas arranca la app. Llamar antes de que termine el launch.
    func registerBackgroundTasks() {
        guard !hasRegisteredBackgroundTasks else { return }
        hasRegisteredBackgroundTasks = true
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshTaskIdentifier, using: nil) { [weak self] task in
            guard let self, let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleRefresh(task: refreshTask)
        }
    }

    // Programá la próxima corrida. Llamar al pasar a background.
    // earliestBeginDate es un piso, no una promesa. iOS puede tardar mucho más.
    func scheduleNext() {
        guard AppSettings.shared.notifDemorasEnabled else { return }
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Self.minimumInterval)
        try? BGTaskScheduler.shared.submit(request)
    }

    // Cancela la corrida programada. Llamar al desactivar el aviso de demoras.
    func cancelScheduled() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshTaskIdentifier)
    }

    // MARK: - Ejecución de la tarea

    private func handleRefresh(task: BGAppRefreshTask) {
        // Reprogramar siempre, corra bien o mal esta corrida.
        scheduleNext()

        let work = Task {
            await checkFavoritesForDelays()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { work.cancel() }
    }

    // Revisa arribos de las estaciones favoritas. Notifica demora nueva (leve o importante).
    private func checkFavoritesForDelays() async {
        guard AppSettings.shared.notifDemorasEnabled else { return }
        // Las notificaciones de demora hoy son solo de tren.
        let stations = FavoritesStore.shared.trainStations
        guard !stations.isEmpty else { return }

        let previous = loadNotifiedCache()
        var current: [String: String] = [:]

        for station in stations {
            guard let arrivals = try? await SofseClient.shared.arrivals(stationId: station.id, limit: 5) else {
                continue
            }
            for arrival in arrivals {
                let bucket: String?
                switch arrival.delay {
                case .major: bucket = "major"
                case .minor: bucket = "minor"
                default: bucket = nil
                }
                guard let bucket else { continue }

                current[arrival.id] = bucket
                if previous[arrival.id] != bucket {
                    await notify(station: station, arrival: arrival, bucket: bucket)
                }
            }
        }
        saveNotifiedCache(current)
    }

    private func notify(station: Station, arrival: Arrival, bucket: String) async {
        let content = UNMutableNotificationContent()
        content.title = bucket == "major" ? "Demora importante" : "Demora leve"
        content.body = "\(arrival.line.shortCode) a \(arrival.destinationName), desde \(station.nombre): \(arrival.delay.label)."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "delay-\(arrival.id)-\(bucket)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Cache de deduplicación

    private func loadNotifiedCache() -> [String: String] {
        guard let data = defaults.data(forKey: Self.notifiedCacheKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func saveNotifiedCache(_ cache: [String: String]) {
        if let data = try? JSONEncoder().encode(cache) {
            defaults.set(data, forKey: Self.notifiedCacheKey)
        }
    }
}
