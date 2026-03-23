import Foundation
import SwiftData

enum Occasion: String, Codable, CaseIterable {
    case work, casual, goingOut = "going_out", active, travel

    var displayName: String {
        switch self {
        case .work: return "Work"
        case .casual: return "Casual"
        case .goingOut: return "Going Out"
        case .active: return "Active"
        case .travel: return "Travel"
        }
    }
}

enum Mood: String, Codable, CaseIterable {
    case comfortable, polished, creative, minimal

    var displayName: String { rawValue.capitalized }
}

@Model
final class Outfit {
    @Attribute(.unique) var id: UUID
    var name: String?
    var itemIDs: [UUID]
    var occasionRaw: String?
    var seasonRaw: String?
    var wornDates: [Date]
    var plannedDate: Date?
    var tryOnRenderFileName: String?
    var isFavorite: Bool
    var userRating: Int?
    var tripID: UUID?
    var createdDate: Date

    var occasion: Occasion? {
        get { occasionRaw.flatMap { Occasion(rawValue: $0) } }
        set { occasionRaw = newValue?.rawValue }
    }

    var season: Season? {
        get { seasonRaw.flatMap { Season(rawValue: $0) } }
        set { seasonRaw = newValue?.rawValue }
    }

    var tryOnRenderURL: URL? {
        guard let fileName = tryOnRenderFileName else { return nil }
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("TryOnRenders").appendingPathComponent(fileName)
    }

    init(
        name: String? = nil,
        itemIDs: [UUID] = [],
        occasion: Occasion? = nil,
        season: Season? = nil,
        plannedDate: Date? = nil,
        isFavorite: Bool = false,
        tripID: UUID? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.itemIDs = itemIDs
        self.occasionRaw = occasion?.rawValue
        self.seasonRaw = season?.rawValue
        self.wornDates = []
        self.plannedDate = plannedDate
        self.tryOnRenderFileName = nil
        self.isFavorite = isFavorite
        self.userRating = nil
        self.tripID = tripID
        self.createdDate = Date()
    }
}
