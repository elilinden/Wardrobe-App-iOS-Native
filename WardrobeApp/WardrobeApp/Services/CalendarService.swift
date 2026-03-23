import Foundation
import EventKit

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let isWorkRelated: Bool

    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }

    var chipLabel: String {
        "\(title) \(timeString)"
    }
}

class CalendarService: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var todayEvents: [CalendarEvent] = []
    @Published var hasAccess: Bool = false

    func requestAccess() async {
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                granted = try await eventStore.requestAccess(to: .event)
            }
            await MainActor.run {
                self.hasAccess = granted
                if granted {
                    self.fetchTodayEvents()
                }
            }
        } catch {
            await MainActor.run {
                self.hasAccess = false
            }
        }
    }

    func fetchTodayEvents() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)

        let workKeywords = ["meeting", "work", "office", "conference", "standup", "review", "interview"]

        todayEvents = events.map { event in
            let titleLower = event.title.lowercased()
            let isWork = workKeywords.contains { titleLower.contains($0) }
            return CalendarEvent(
                id: event.eventIdentifier,
                title: event.title,
                startDate: event.startDate,
                isWorkRelated: isWork
            )
        }.sorted { $0.startDate < $1.startDate }
    }
}
