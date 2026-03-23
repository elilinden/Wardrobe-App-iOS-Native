import Foundation
import SwiftData

enum Activity: String, Codable, CaseIterable {
    case beach
    case cityExploring = "city_exploring"
    case businessMeetings = "business_meetings"
    case casualDinners = "casual_dinners"
    case fineDining = "fine_dining"
    case hiking, active
    case formalEvents = "formal_events"

    var displayName: String {
        switch self {
        case .beach: return "Beach"
        case .cityExploring: return "City Exploring"
        case .businessMeetings: return "Business Meetings"
        case .casualDinners: return "Casual Dinners"
        case .fineDining: return "Fine Dining"
        case .hiking: return "Hiking"
        case .active: return "Active"
        case .formalEvents: return "Formal Events"
        }
    }

    var icon: String {
        switch self {
        case .beach: return "beach.umbrella"
        case .cityExploring: return "building.2"
        case .businessMeetings: return "briefcase"
        case .casualDinners: return "fork.knife"
        case .fineDining: return "wineglass"
        case .hiking: return "figure.hiking"
        case .active: return "figure.run"
        case .formalEvents: return "star"
        }
    }

    var requiredFormalities: Set<Formality> {
        switch self {
        case .businessMeetings, .formalEvents, .fineDining:
            return [.formal, .smartCasual]
        case .hiking, .active, .beach:
            return [.athletic, .casual]
        case .cityExploring, .casualDinners:
            return [.casual, .smartCasual]
        }
    }
}

@Model
final class PackingTrip {
    @Attribute(.unique) var id: UUID
    var name: String
    var destination: String
    var startDate: Date
    var endDate: Date
    var activitiesRaw: [String]
    var packedItemIDs: [UUID]
    var outfitCombinationIDs: [UUID]

    var activities: [Activity] {
        get { activitiesRaw.compactMap { Activity(rawValue: $0) } }
        set { activitiesRaw = newValue.map(\.rawValue) }
    }

    var numberOfDays: Int {
        max(1, (Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1)
    }

    var dateRangeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }

    var displayName: String {
        name.isEmpty ? destination : name
    }

    init(
        name: String = "",
        destination: String = "",
        startDate: Date = Date(),
        endDate: Date = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
        activities: [Activity] = []
    ) {
        self.id = UUID()
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.activitiesRaw = activities.map(\.rawValue)
        self.packedItemIDs = []
        self.outfitCombinationIDs = []
    }
}
