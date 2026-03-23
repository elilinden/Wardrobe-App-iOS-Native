import Foundation
import SwiftData

struct OutfitSuggestion: Identifiable {
    let id = UUID()
    let items: [WardrobeItem]
    let reason: String
    var score: Double
}

class SuggestionEngine {
    private let matrix = CompatibilityMatrix.load()

    func generateSuggestions(
        allItems: [WardrobeItem],
        weather: WeatherInfo?,
        events: [CalendarEvent],
        occasion: Occasion?,
        mood: Mood?,
        recentOutfits: [Outfit],
        thumbsDownHistory: Set<Set<UUID>>,
        reWearGapDays: Int,
        weatherSensitivity: Float
    ) -> [OutfitSuggestion] {
        // Filter available items
        let available = allItems.filter { item in
            !item.isWishlist &&
            item.condition != .needsCleaning &&
            item.condition != .needsTailoring &&
            item.condition != .inStorage
        }

        let tops = available.filter { $0.category == .top }
        let bottoms = available.filter { $0.category == .bottom }
        let dresses = available.filter { $0.category == .dress }
        let outerwear = available.filter { $0.category == .outerwear }
        let shoes = available.filter { $0.category == .shoes }

        var suggestions: [OutfitSuggestion] = []

        // Generate top+bottom combinations
        for top in tops {
            for bottom in bottoms {
                for shoe in shoes.prefix(3) {
                    let items = [top, bottom, shoe]
                    if let suggestion = scoreCombination(
                        items: items,
                        weather: weather,
                        events: events,
                        occasion: occasion,
                        mood: mood,
                        recentOutfits: recentOutfits,
                        thumbsDownHistory: thumbsDownHistory,
                        reWearGapDays: reWearGapDays,
                        weatherSensitivity: weatherSensitivity
                    ) {
                        suggestions.append(suggestion)
                    }
                }
            }
        }

        // Generate dress combinations
        for dress in dresses {
            for shoe in shoes.prefix(3) {
                let items = [dress, shoe]
                if let suggestion = scoreCombination(
                    items: items,
                    weather: weather,
                    events: events,
                    occasion: occasion,
                    mood: mood,
                    recentOutfits: recentOutfits,
                    thumbsDownHistory: thumbsDownHistory,
                    reWearGapDays: reWearGapDays,
                    weatherSensitivity: weatherSensitivity
                ) {
                    suggestions.append(suggestion)
                }
            }
        }

        // Sort by score descending and return top 3
        suggestions.sort { $0.score > $1.score }
        return Array(suggestions.prefix(3))
    }

    private func scoreCombination(
        items: [WardrobeItem],
        weather: WeatherInfo?,
        events: [CalendarEvent],
        occasion: Occasion?,
        mood: Mood?,
        recentOutfits: [Outfit],
        thumbsDownHistory: Set<Set<UUID>>,
        reWearGapDays: Int,
        weatherSensitivity: Float
    ) -> OutfitSuggestion? {
        let itemIDs = Set(items.map(\.id))
        var score: Double = 100.0
        var reasons: [String] = []

        // Rule 9: Thumbs-down history — immediately disqualify
        if thumbsDownHistory.contains(itemIDs) {
            return nil
        }

        // Rule 8: Compatibility matrix — never combine
        for pair in matrix.neverCombine {
            guard pair.count == 2 else { continue }
            let hasFirst = items.contains { $0.subcategory.lowercased().contains(pair[0].replacingOccurrences(of: "_", with: " ")) || $0.formalityRaw == pair[0] }
            let hasSecond = items.contains { $0.subcategory.lowercased().contains(pair[1].replacingOccurrences(of: "_", with: " ")) || $0.formalityRaw == pair[1] }
            if hasFirst && hasSecond {
                return nil
            }
        }

        // Preferred combinations bonus
        for pair in matrix.preferCombine {
            guard pair.count == 2 else { continue }
            let hasFirst = items.contains { $0.subcategory.lowercased().contains(pair[0].replacingOccurrences(of: "_", with: " ")) }
            let hasSecond = items.contains { $0.subcategory.lowercased().contains(pair[1].replacingOccurrences(of: "_", with: " ")) }
            if hasFirst && hasSecond {
                score += 10
            }
        }

        // Rule 2: Weather filtering
        if let weather = weather {
            let temp = weather.currentTemp
            let sensitivity = Double(weatherSensitivity)

            if temp < 55 {
                for item in items {
                    if item.subcategory.lowercased().contains("short") || item.subcategory.lowercased().contains("sleeveless") || item.subcategory.lowercased().contains("tank") {
                        score -= 50 * sensitivity
                    }
                }
                // Bonus for outerwear in cold
                if items.contains(where: { $0.category == .outerwear }) {
                    score += 15 * sensitivity
                }
            }

            if temp > 75 {
                for item in items {
                    if item.category == .outerwear && item.subcategory.lowercased().contains("heavy") {
                        score -= 50 * sensitivity
                    }
                }
            }

            reasons.append("Matches today's weather (\(Int(temp))°)")
        }

        // Rule 3: Occasion filtering
        if let occasion = occasion {
            let targetFormality: Formality = switch occasion {
            case .work: .smartCasual
            case .casual: .casual
            case .goingOut: .smartCasual
            case .active: .athletic
            case .travel: .casual
            }

            for item in items {
                if item.formality == targetFormality {
                    score += 10
                }
            }
        }

        // Rule 4: Calendar-based bias
        let hasWorkEvent = events.contains { $0.isWorkRelated }
        if hasWorkEvent {
            for item in items {
                if item.formality == .smartCasual || item.formality == .formal {
                    score += 15
                }
                if item.formality == .athletic || item.formality == .casual {
                    score -= 10
                }
            }
            if let event = events.first(where: { $0.isWorkRelated }) {
                reasons.append("Good for your \(event.timeString) meeting")
            }
        }

        // Rule 5 & 6: Wear recency
        let now = Date()
        for item in items {
            if let lastWorn = item.lastWorn {
                let daysSince = Calendar.current.dateComponents([.day], from: lastWorn, to: now).day ?? 0
                if daysSince < 7 {
                    score -= 20 // Rule 5: Deprioritize recently worn
                }
                if daysSince >= 21 {
                    score += 15 // Rule 6: Prioritize unworn items
                    reasons.append("You haven't worn \(item.name ?? item.subcategory) in \(daysSince) days")
                }
            } else {
                score += 10 // Never worn bonus
            }
        }

        // Rule 7: No repeat outfits in re-wear gap
        let recentItemSets = recentOutfits
            .filter { outfit in
                guard let lastWorn = outfit.wornDates.last else { return false }
                let days = Calendar.current.dateComponents([.day], from: lastWorn, to: now).day ?? 0
                return days < reWearGapDays
            }
            .map { Set($0.itemIDs) }

        if recentItemSets.contains(itemIDs) {
            return nil
        }

        if reasons.isEmpty {
            reasons.append("Great combination for today")
        }

        return OutfitSuggestion(
            items: items,
            reason: reasons.first ?? "Great combination for today",
            score: max(0, score)
        )
    }
}
