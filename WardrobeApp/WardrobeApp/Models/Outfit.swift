import Foundation
import SwiftData

enum Occasion: String, Codable, CaseIterable {
    case work, casual
    case goingOut = "going_out"
    case active, travel

    var displayName: String {
        switch self {
        case .work: return "Work"
        case .casual: return "Casual"
        case .goingOut: return "Going Out"
        case .active: return "Active"
        case .travel: return "Travel"
        }
    }

    var icon: String {
        switch self {
        case .work: return "briefcase"
        case .casual: return "cup.and.saucer"
        case .goingOut: return "party.popper"
        case .active: return "figure.run"
        case .travel: return "airplane"
        }
    }
}

enum Mood: String, Codable, CaseIterable {
    case comfortable, polished, creative, minimal

    var displayName: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .comfortable: return "cloud"
        case .polished: return "sparkle"
        case .creative: return "paintbrush"
        case .minimal: return "minus.circle"
        }
    }
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
    var userRating: Int? // thumbs: 1 = down, 2 = up
    var tripID: UUID?
    var createdDate: Date

    // MARK: Computed Properties

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
        return FileStorage.tryOnRenderURL(fileName: fileName)
    }

    var displayName: String {
        name ?? "Outfit"
    }

    var lastWornFormatted: String? {
        guard let lastWorn = wornDates.last else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastWorn, relativeTo: Date())
    }

    var itemIDSet: Set<UUID> {
        Set(itemIDs)
    }

    // MARK: Init

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

    // MARK: Actions

    func markWorn(items: [WardrobeItem]) {
        wornDates.append(Date())
        for item in items {
            item.markWornToday()
        }
        Haptic.medium()
    }

    func cleanupRender() {
        if let url = tryOnRenderURL {
            ImageCache.shared.invalidate(for: url)
            FileStorage.deleteFile(at: url)
        }
    }

    func resolveItems(from allItems: [WardrobeItem]) -> [WardrobeItem] {
        itemIDs.compactMap { id in
            allItems.first { $0.id == id }
        }
    }
}
