import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    func requestPermission() async -> Bool {
        AppLog.notifications.info("Requesting notification permission")
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            AppLog.notifications.info("Notification permission: \(granted ? "granted" : "denied")")
            return granted
        } catch {
            AppLog.notifications.error("Notification permission error: \(error.localizedDescription)")
            return false
        }
    }

    func scheduleMorningSuggestion(hour: Int, minute: Int) {
        AppLog.notifications.info("Scheduling morning suggestion at \(hour):\(minute)")
        let id = "morning_outfit_suggestion"
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "What to wear today"
        content.body = "Check out today's outfit suggestions based on your weather and calendar."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        center.add(request) { error in
            if let error {
                AppLog.notifications.error("Failed to schedule morning notification: \(error.localizedDescription)")
            } else {
                AppLog.notifications.info("Morning notification scheduled at \(hour):\(minute)")
            }
        }
    }

    func scheduleEveningReminder(hour: Int, minute: Int) {
        AppLog.notifications.info("Scheduling evening reminder at \(hour):\(minute)")
        let id = "evening_outfit_reminder"
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "Plan tomorrow's outfit"
        content.body = "Pick what you'll wear tomorrow so your morning is stress-free."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        center.add(request) { error in
            if let error {
                AppLog.notifications.error("Failed to schedule evening reminder: \(error.localizedDescription)")
            }
        }
    }

    func cancelAll() {
        AppLog.notifications.info("Cancelling all notifications")
        center.removeAllPendingNotificationRequests()
    }

    func cancelMorningSuggestion() {
        AppLog.notifications.info("Cancelling morning suggestion")
        center.removePendingNotificationRequests(withIdentifiers: ["morning_outfit_suggestion"])
    }

    func cancelEveningReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["evening_outfit_reminder"])
    }
}
