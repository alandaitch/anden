import Foundation
import Observation

// Ajustes de la app. Persiste en App Group.
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults: UserDefaults

    var notifDemorasEnabled: Bool {
        didSet { defaults.set(notifDemorasEnabled, forKey: "settings.notifDemoras") }
    }
    var seguirServicioId: String? {
        didSet { defaults.set(seguirServicioId, forKey: "settings.seguirServicioId") }
    }
    var onboardingDone: Bool {
        didSet { defaults.set(onboardingDone, forKey: "settings.onboardingDone") }
    }

    init(defaults: UserDefaults? = nil) {
        let d = defaults ?? (UserDefaults(suiteName: "group.com.alandaitch.anden") ?? .standard)
        self.defaults = d
        self.notifDemorasEnabled = d.bool(forKey: "settings.notifDemoras")
        self.seguirServicioId = d.string(forKey: "settings.seguirServicioId")
        self.onboardingDone = d.bool(forKey: "settings.onboardingDone")
    }
}
