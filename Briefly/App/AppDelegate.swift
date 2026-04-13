import BackgroundTasks
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    private let refreshTaskId = "com.briefly.refresh"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AnalyticsService.configureIfAvailable()
        registerBackgroundTasks()
        scheduleRefresh()
        return true
    }

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskId, using: nil) { task in
            self.handleRefresh(task: task as! BGAppRefreshTask)
        }
    }

    private func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60 * 6)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleRefresh(task: BGAppRefreshTask) {
        scheduleRefresh()
        task.expirationHandler = {}
        task.setTaskCompleted(success: true)
    }
}
