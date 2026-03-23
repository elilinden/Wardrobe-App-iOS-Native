import Foundation
import SwiftData

// MARK: - Enums

enum Category: String, Codable, CaseIterable, Identifiable {
    case top, bottom, dress, outerwear, shoes, accessory
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .top: return "Tops"
        case .bottom: return "Bottoms"
        case .dress: return "Dresses"
        case .outerwear: return "Outerwear"
        case .shoes: return "Shoes"
        case .accessory: return "Accessories"
        }
    }

    var icon: String {
        switch self {
        case .top: return "tshirt"
        case .bottom: return "figure.walk"
        case .dress: return "figure.dress.line.vertical.figure"
        case .outerwear: return "cloud.snow"
        case .shoes: return "shoe"
        case .accessory: return "sparkles"
        }
    }
}

enum Pattern: String, Codable, CaseIterable {
    case solid, striped, plaid, floral, graphic, other

    var displayName: String { rawValue.capitalized }
}

enum Material: String, Codable, CaseIterable {
    case denim, knit, cotton, silk, leather, synthetic, unknown

    var displayName: String { rawValue.capitalized }
}

enum Formality: String, Codable, CaseIterable {
    case casual
    case smartCasual = "smart_casual"
    case formal
    case athletic

    var displayName: String {
        switch self {
        case .casual: return "Casual"
        case .smartCasual: return "Smart Casual"
        case .formal: return "Formal"
        case .athletic: return "Athletic"
        }
    }
}

enum Season: String, Codable, CaseIterable {
    case spring, summer, fall, winter
    case yearRound = "year_round"

    var displayName: String {
        switch self {
        case .yearRound: return "Year-round"
        default: return rawValue.capitalized
        }
    }
}

enum ItemCondition: String, Codable, CaseIterable {
    case clean
    case needsCleaning = "needs_cleaning"
    case needsTailoring = "needs_tailoring"
    case inStorage = "in_storage"

    var displayName: String {
        switch self {
        case .clean: return "Clean"
        case .needsCleaning: return "Needs Cleaning"
        case .needsTailoring: return "Needs Tailoring"
        case .inStorage: return "In Storage"
        }
    }

    var icon: String {
        switch self {
        case .clean: return "checkmark.circle"
        case .needsCleaning: return "drop.triangle"
        case .needsTailoring: return "scissors"
        case .inStorage: return "archivebox"
        }
    }

    var isAvailable: Bool {
        self == .clean
    }
}

// MARK: - Model

@Model
final class WardrobeItem {
    @Attribute(.unique) var id: UUID
    var name: String?
    var brand: String?
    var categoryRaw: String
    var subcategory: String
    var primaryColor: String
    var secondaryColor: String?
    var patternRaw: String
    var materialEstimateRaw: String
    var formalityRaw: String
    var seasonsRaw: [String]
    var purchasePrice: Double?
    var dateAdded: Date
    var conditionRaw: String
    var timesWorn: Int
    var lastWorn: Date?
    var photoFileName: String
    var isWishlist: Bool
    var notes: String?

    // MARK: Computed Properties

    var category: Category {
        get { Category(rawValue: categoryRaw) ?? .top }
        set { categoryRaw = newValue.rawValue }
    }

    var pattern: Pattern {
        get { Pattern(rawValue: patternRaw) ?? .solid }
        set { patternRaw = newValue.rawValue }
    }

    var materialEstimate: Material {
        get { Material(rawValue: materialEstimateRaw) ?? .unknown }
        set { materialEstimateRaw = newValue.rawValue }
    }

    var formality: Formality {
        get { Formality(rawValue: formalityRaw) ?? .casual }
        set { formalityRaw = newValue.rawValue }
    }

    var seasons: [Season] {
        get { seasonsRaw.compactMap { Season(rawValue: $0) } }
        set { seasonsRaw = newValue.map(\.rawValue) }
    }

    var condition: ItemCondition {
        get { ItemCondition(rawValue: conditionRaw) ?? .clean }
        set { conditionRaw = newValue.rawValue }
    }

    var photoURL: URL {
        FileStorage.itemPhotoURL(fileName: photoFileName)
    }

    var costPerWear: Double? {
        guard let price = purchasePrice, timesWorn > 0 else { return nil }
        return price / Double(timesWorn)
    }

    var costPerWearFormatted: String {
        guard let cpw = costPerWear else { return "—" }
        return String(format: "$%.2f", cpw)
    }

    var displayName: String {
        name ?? subcategory.capitalized
    }

    var daysSinceLastWorn: Int? {
        guard let lastWorn else { return nil }
        return Calendar.current.dateComponents([.day], from: lastWorn, to: Date()).day
    }

    var lastWornFormatted: String {
        guard let lastWorn else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastWorn, relativeTo: Date())
    }

    // MARK: Init

    init(
        name: String? = nil,
        brand: String? = nil,
        category: Category = .top,
        subcategory: String = "",
        primaryColor: String = "Unknown",
        secondaryColor: String? = nil,
        pattern: Pattern = .solid,
        materialEstimate: Material = .unknown,
        formality: Formality = .casual,
        seasons: [Season] = [.yearRound],
        purchasePrice: Double? = nil,
        condition: ItemCondition = .clean,
        isWishlist: Bool = false,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.brand = brand
        self.categoryRaw = category.rawValue
        self.subcategory = subcategory.isEmpty ? category.rawValue : subcategory
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.patternRaw = pattern.rawValue
        self.materialEstimateRaw = materialEstimate.rawValue
        self.formalityRaw = formality.rawValue
        self.seasonsRaw = seasons.map(\.rawValue)
        self.purchasePrice = purchasePrice
        self.dateAdded = Date()
        self.conditionRaw = condition.rawValue
        self.timesWorn = 0
        self.lastWorn = nil
        self.photoFileName = "\(UUID().uuidString).jpg"
        self.isWishlist = isWishlist
        self.notes = notes
    }

    // MARK: Actions

    func markWornToday() {
        timesWorn += 1
        lastWorn = Date()
        Haptic.light()
    }

    func moveToStorage() {
        condition = .inStorage
    }

    func convertFromWishlist() {
        isWishlist = false
        dateAdded = Date()
        Haptic.success()
    }

    func cleanupPhoto() {
        ImageCache.shared.invalidate(for: photoURL)
        FileStorage.deleteFile(at: photoURL)
    }
}
