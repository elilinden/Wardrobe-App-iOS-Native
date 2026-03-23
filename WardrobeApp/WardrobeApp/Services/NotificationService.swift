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

        center.add(request)
    }

    func scheduleEveningReminder(hour: Int, minute: Int) {
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

        center.add(request)
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    func cancelMorningSuggestion() {
        center.removePendingNotificationRequests(withIdentifiers: ["morning_outfit_suggestion"])
    }

    func cancelEveningReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["evening_outfit_reminder"])
    }
}
