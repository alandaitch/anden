import SwiftUI

@main
struct AndenApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var appSettings = AppSettings.shared

    init() {
        // BGTaskScheduler exige registro temprano, antes de terminar el launch.
        NotificationManager.shared.registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .fullScreenCover(isPresented: Binding(
                    get: { !appSettings.onboardingDone },
                    set: { _ in }
                )) {
                    OnboardingView()
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        Task { await WidgetSnapshot.refreshFromApp() }
                    case .background:
                        NotificationManager.shared.scheduleNext()
                    default:
                        break
                    }
                }
        }
    }
}
