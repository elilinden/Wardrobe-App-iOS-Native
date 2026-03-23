import Foundation

struct OutfitSuggestion: Identifiable {
    let id = UUID()
    let items: [WardrobeItem]
    let reasons: [String]
    var score: Double

    var primaryReason: String {
        reasons.first ?? "Great combination for today"
    }
}

class SuggestionEngine {
    private let matrix = CompatibilityMatrix.load()
    private let maxCombinations = 500 // Performance cap

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
        let available = allItems.filter { $0.condition.isAvailable && !$0.isWishlist }

        let tops = available.filter { $0.category == .top }.shuffled()
        let bottoms = available.filter { $0.category == .bottom }.shuffled()
        let dresses = available.filter { $0.category == .dress }.shuffled()
        let shoes = available.filter { $0.category == .shoes }.shuffled()

        var suggestions: [OutfitSuggestion] = []
        var combinationCount = 0

        // Top + Bottom + Shoes combos (capped for performance)
        outerLoop: for top in tops.prefix(10) {
            for bottom in bottoms.prefix(8) {
                for shoe in shoes.prefix(4) {
                    guard combinationCount < maxCombinations else { break outerLoop }
                    combinationCount += 1

                    if let s = score(
                        items: [top, bottom, shoe],
                        weather: weather, events: events,
                        occasion: occasion, mood: mood,
                        recentOutfits: recentOutfits,
                        thumbsDownHistory: thumbsDownHistory,
                        reWearGapDays: reWearGapDays,
                        weatherSensitivity: weatherSensitivity
                    ) {
                        suggestions.append(s)
                    }
                }
            }
        }

        // Dress + Shoes combos
        for dress in dresses.prefix(6) {
            for shoe in shoes.prefix(4) {
                guard combinationCount < maxCombinations else { break }
                combinationCount += 1

                if let s = score(
                    items: [dress, shoe],
                    weather: weather, events: events,
                    occasion: occasion, mood: mood,
                    recentOutfits: recentOutfits,
                    thumbsDownHistory: thumbsDownHistory,
                    reWearGapDays: reWearGapDays,
                    weatherSensitivity: weatherSensitivity
                ) {
                    suggestions.append(s)
                }
            }
        }

        suggestions.sort { $0.score > $1.score }
        return Array(suggestions.prefix(3))
    }

    // MARK: - Scoring

    private func score(
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

        // Rule 9: Thumbs-down — disqualify
        if thumbsDownHistory.contains(itemIDs) { return nil }

        // Rule 8: Compatibility matrix — never combine
        if violatesCompatibility(items) { return nil }

        // Preferred combinations bonus
        score += preferredCombinationBonus(items)

        // Rule 7: No repeat outfits
        let now = Date()
        let recentItemSets = recentOutfits
            .filter { outfit in
                guard let lastWorn = outfit.wornDates.last else { return false }
                let days = Calendar.current.dateComponents([.day], from: lastWorn, to: now).day ?? 0
                return days < reWearGapDays
            }
            .map { $0.itemIDSet }

        if recentItemSets.contains(itemIDs) { return nil }

        // Rule 2: Weather
        if let weather {
            let (weatherScore, weatherReason) = scoreWeather(items: items, weather: weather, sensitivity: weatherSensitivity)
            score += weatherScore
            if let r = weatherReason { reasons.append(r) }
        }

        // Rule 3: Occasion
        if let occasion {
            score += scoreOccasion(items: items, occasion: occasion)
        }

        // Rule 4: Calendar
        let (calScore, calReason) = scoreCalendar(items: items, events: events)
        score += calScore
        if let r = calReason { reasons.append(r) }

        // Rules 5 & 6: Wear recency
        let (wearScore, wearReasons) = scoreWearHistory(items: items)
        score += wearScore
        reasons.append(contentsOf: wearReasons)

        if reasons.isEmpty {
            reasons.append("Great combination for today")
        }

        guard score > 0 else { return nil }

        return OutfitSuggestion(items: items, reasons: reasons, score: score)
    }

    // MARK: - Sub-scoring

    private func violatesCompatibility(_ items: [WardrobeItem]) -> Bool {
        for pair in matrix.neverCombine where pair.count == 2 {
            let normalized = pair.map { $0.replacingOccurrences(of: "_", with: " ") }
            let hasFirst = items.contains {
                $0.subcategory.lowercased().contains(normalized[0]) ||
                $0.formalityRaw.replacingOccurrences(of: "_", with: " ") == normalized[0]
            }
            let hasSecond = items.contains {
                $0.subcategory.lowercased().contains(normalized[1]) ||
                $0.formalityRaw.replacingOccurrences(of: "_", with: " ") == normalized[1]
            }
            if hasFirst && hasSecond { return true }
        }
        return false
    }

    private func preferredCombinationBonus(_ items: [WardrobeItem]) -> Double {
        var bonus: Double = 0
        for pair in matrix.preferCombine where pair.count == 2 {
            let normalized = pair.map { $0.replacingOccurrences(of: "_", with: " ") }
            let hasFirst = items.contains { $0.subcategory.lowercased().contains(normalized[0]) }
            let hasSecond = items.contains { $0.subcategory.lowercased().contains(normalized[1]) }
            if hasFirst && hasSecond { bonus += 10 }
        }
        return bonus
    }

    private func scoreWeather(items: [WardrobeItem], weather: WeatherInfo, sensitivity: Float) -> (Double, String?) {
        let temp = weather.currentTemp
        let s = Double(sensitivity)
        var delta: Double = 0

        if temp < 55 {
            for item in items {
                let sub = item.subcategory.lowercased()
                if sub.contains("short") || sub.contains("sleeveless") || sub.contains("tank") {
                    delta -= 50 * s
                }
            }
            if items.contains(where: { $0.category == .outerwear }) {
                delta += 15 * s
            }
        }

        if temp > 75 {
            for item in items where item.category == .outerwear {
                if item.subcategory.lowercased().contains("heavy") || item.materialEstimate == .leather {
                    delta -= 50 * s
                }
            }
        }

        return (delta, "Matches today's weather (\(Int(temp))°)")
    }

    private func scoreOccasion(items: [WardrobeItem], occasion: Occasion) -> Double {
        let target: Formality = switch occasion {
        case .work: .smartCasual
        case .casual: .casual
        case .goingOut: .smartCasual
        case .active: .athletic
        case .travel: .casual
        }

        return items.reduce(0.0) { sum, item in
            sum + (item.formality == target ? 10 : 0)
        }
    }

    private func scoreCalendar(items: [WardrobeItem], events: [CalendarEvent]) -> (Double, String?) {
        guard let workEvent = events.first(where: \.isWorkRelated) else { return (0, nil) }

        var delta: Double = 0
        for item in items {
            if item.formality == .smartCasual || item.formality == .formal {
                delta += 15
            } else if item.formality == .athletic {
                delta -= 10
            }
        }

        return (delta, "Good for your \(workEvent.timeString) meeting")
    }

    private func scoreWearHistory(items: [WardrobeItem]) -> (Double, [String]) {
        var delta: Double = 0
        var reasons: [String] = []
        let now = Date()

        for item in items {
            if let lastWorn = item.lastWorn {
                let days = Calendar.current.dateComponents([.day], from: lastWorn, to: now).day ?? 0
                if days < 7 {
                    delta -= 20 // Rule 5
                }
                if days >= 21 {
                    delta += 15 // Rule 6
                    reasons.append("You haven't worn \(item.displayName) in \(days) days")
                }
            } else {
                delta += 10 // Never worn bonus
            }
        }

        return (delta, reasons)
    }
}
