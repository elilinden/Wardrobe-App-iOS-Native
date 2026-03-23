import Foundation
import SwiftData

enum Activity: String, Codable, CaseIterable {
    case beach, cityExploring = "city_exploring", businessMeetings = "business_meetings"
    case casualDinners = "casual_dinners", fineDining = "fine_dining"
    case hiking, active, formalEvents = "formal_events"

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
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }

    init(
        name: String = "",
        destination: String = "",
        startDate: Date = Date(),
        endDate: Date = Date(),
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
