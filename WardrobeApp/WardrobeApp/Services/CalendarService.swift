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
    @Published var hasAccess = false

    private static let workKeywords = [
        "meeting", "work", "office", "conference", "standup",
        "review", "interview", "sync", "presentation", "call"
    ]

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
                if granted { self.fetchTodayEvents() }
            }
        } catch {
            await MainActor.run { self.hasAccess = false }
        }
    }

    func fetchTodayEvents() {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }

        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)

        todayEvents = events.map { event in
            let titleLower = event.title?.lowercased() ?? ""
            let isWork = Self.workKeywords.contains { titleLower.contains($0) }
            return CalendarEvent(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "Event",
                startDate: event.startDate,
                isWorkRelated: isWork
            )
        }
        .sorted { $0.startDate < $1.startDate }
    }
}
