import Foundation
import UserNotifications

@MainActor
final class NotificationManager: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        refreshStatus()
    }

    func refreshStatus() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            authorizationStatus = settings.authorizationStatus
        }
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            refreshStatus()
            return granted
        } catch {
            return false
        }
    }

    func scheduleDailyCheckIn(hour: Int = 9, minute: Int = 0) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["briefly.daily_checkin"])

        var date = DateComponents()
        date.hour = hour
        date.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let content = UNMutableNotificationContent()
        content.title = "Briefly"
        content.body = "Check in today so we can update your next best action."
        content.sound = .default

        let req = UNNotificationRequest(identifier: "briefly.daily_checkin", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(req)
    }

    func scheduleActionFollowUp(actionTitle: String, actionId: UUID, date: Date) async {
        let id = "briefly.action.\(actionId.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "Follow up"
        content.body = "Follow up on: \(actionTitle)"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, date.timeIntervalSinceNow), repeats: false)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(req)
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
