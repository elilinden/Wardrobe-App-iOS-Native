import Foundation
import SwiftData

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
}

enum Pattern: String, Codable, CaseIterable {
    case solid, striped, plaid, floral, graphic, other
}

enum Material: String, Codable, CaseIterable {
    case denim, knit, cotton, silk, leather, synthetic, unknown
}

enum Formality: String, Codable, CaseIterable {
    case casual, smartCasual = "smart_casual", formal, athletic

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
    case spring, summer, fall, winter, yearRound = "year_round"

    var displayName: String {
        switch self {
        case .spring: return "Spring"
        case .summer: return "Summer"
        case .fall: return "Fall"
        case .winter: return "Winter"
        case .yearRound: return "Year-round"
        }
    }
}

enum ItemCondition: String, Codable, CaseIterable {
    case clean, needsCleaning = "needs_cleaning", needsTailoring = "needs_tailoring", inStorage = "in_storage"

    var displayName: String {
        switch self {
        case .clean: return "Clean"
        case .needsCleaning: return "Needs Cleaning"
        case .needsTailoring: return "Needs Tailoring"
        case .inStorage: return "In Storage"
        }
    }
}

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

    var costPerWear: Double? {
        guard let price = purchasePrice, timesWorn > 0 else { return nil }
        return price / Double(timesWorn)
    }

    var photoURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("ItemPhotos").appendingPathComponent(photoFileName)
    }

    init(
        name: String? = nil,
        brand: String? = nil,
        category: Category = .top,
        subcategory: String = "",
        primaryColor: String = "",
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
        self.subcategory = subcategory
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
}
