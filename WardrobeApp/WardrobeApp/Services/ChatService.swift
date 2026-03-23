import SwiftUI
import SwiftData

// MARK: - Bot Definitions

enum BotPersonality: String, CaseIterable, Identifiable, Codable {
    case stylist = "stylist"
    case minimalist = "minimalist"
    case trendy = "trendy"
    case sustainable = "sustainable"
    case colorExpert = "color_expert"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .stylist: return "Style Advisor"
        case .minimalist: return "Minimalist Coach"
        case .trendy: return "Trend Spotter"
        case .sustainable: return "Eco Stylist"
        case .colorExpert: return "Color Expert"
        }
    }

    var icon: String {
        switch self {
        case .stylist: return "sparkles"
        case .minimalist: return "cube"
        case .trendy: return "flame"
        case .sustainable: return "leaf"
        case .colorExpert: return "paintpalette"
        }
    }

    var accentColor: Color {
        switch self {
        case .stylist: return .purple
        case .minimalist: return .gray
        case .trendy: return .orange
        case .sustainable: return .green
        case .colorExpert: return .blue
        }
    }

    var tagline: String {
        switch self {
        case .stylist: return "Your personal style advisor"
        case .minimalist: return "Less is more — build a capsule wardrobe"
        case .trendy: return "What's hot right now"
        case .sustainable: return "Eco-friendly fashion choices"
        case .colorExpert: return "Master your color palette"
        }
    }

    var systemPrompt: String {
        switch self {
        case .stylist:
            return """
            You are a warm, encouraging personal style advisor. Help users put together outfits, \
            suggest what to wear for specific occasions, and give compliments on good combinations. \
            Be specific about which items from their wardrobe work well together and why. \
            Keep responses concise (2-4 sentences) and actionable.
            """
        case .minimalist:
            return """
            You are a minimalist capsule wardrobe coach. Help users identify their most versatile pieces, \
            suggest items to remove or donate, and build a lean wardrobe where everything works together. \
            Focus on quality over quantity. Recommend neutral color palettes and timeless silhouettes. \
            Keep responses concise and direct.
            """
        case .trendy:
            return """
            You are an enthusiastic trend spotter. Help users incorporate current fashion trends \
            using pieces they already own. Suggest creative styling tricks, layering ideas, and \
            unexpected combinations. Be fun and energetic. Reference current fashion movements \
            without being pushy about buying new items.
            """
        case .sustainable:
            return """
            You are an eco-conscious fashion advisor. Help users maximize what they own, suggest \
            upcycling ideas, recommend sustainable care practices, and encourage mindful purchasing. \
            Calculate cost-per-wear to show value. Celebrate re-wearing and creative reuse. \
            Be encouraging, never preachy.
            """
        case .colorExpert:
            return """
            You are a color theory expert applied to fashion. Help users understand their best colors, \
            create harmonious outfits using complementary/analogous color schemes, and avoid clashing combinations. \
            Reference specific colors from their wardrobe. Explain the "why" behind color pairings briefly.
            """
        }
    }
}

// MARK: - Chat Message Model

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    let botPersonality: BotPersonality?

    enum MessageRole: String, Codable {
        case user
        case assistant
        case system
    }

    init(role: MessageRole, content: String, bot: BotPersonality? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.botPersonality = bot
    }
}

// MARK: - Chat Service

@MainActor
class ChatService: ObservableObject {
    @Published var conversations: [BotPersonality: [ChatMessage]] = [:]
    @Published var isTyping = false

    private let maxHistory = 20

    func sendMessage(_ text: String, to bot: BotPersonality, wardrobeContext: WardrobeContext) async {
        AppLog.api.info("Chat: Sending message to \(bot.displayName)")

        let userMessage = ChatMessage(role: .user, content: text)
        appendMessage(userMessage, to: bot)

        isTyping = true

        // Build context-aware response
        let response = await generateResponse(for: text, bot: bot, context: wardrobeContext)

        let botMessage = ChatMessage(role: .assistant, content: response, bot: bot)
        appendMessage(botMessage, to: bot)

        isTyping = false
        AppLog.api.info("Chat: Response generated for \(bot.displayName)")
    }

    func clearConversation(for bot: BotPersonality) {
        conversations[bot] = []
        AppLog.ui.info("Chat: Cleared conversation for \(bot.displayName)")
    }

    private func appendMessage(_ message: ChatMessage, to bot: BotPersonality) {
        if conversations[bot] == nil {
            conversations[bot] = []
        }
        conversations[bot]?.append(message)

        // Trim old messages
        if let count = conversations[bot]?.count, count > maxHistory {
            conversations[bot]?.removeFirst(count - maxHistory)
        }
    }

    // MARK: - Response Generation

    private func generateResponse(for input: String, bot: BotPersonality, context: WardrobeContext) async -> String {
        // Try Gemini API first, fall back to rule-based
        do {
            let apiKey = APIKeyManager.shared.geminiAPIKey ?? ""
            guard !apiKey.isEmpty else {
                AppLog.api.info("Chat: No API key, using rule-based response")
                return ruleBasedResponse(for: input, bot: bot, context: context)
            }

            let prompt = buildPrompt(for: input, bot: bot, context: context)
            let response = try await callGeminiChat(prompt: prompt, apiKey: apiKey)
            return response
        } catch {
            AppLog.api.error("Chat: Gemini API failed: \(error.localizedDescription), falling back to rules")
            return ruleBasedResponse(for: input, bot: bot, context: context)
        }
    }

    private func buildPrompt(for input: String, bot: BotPersonality, context: WardrobeContext) -> String {
        var prompt = bot.systemPrompt + "\n\n"

        // Add wardrobe context
        prompt += "The user's wardrobe contains:\n"
        for (category, count) in context.categoryCounts {
            prompt += "- \(count) \(category)\n"
        }
        if !context.topColors.isEmpty {
            prompt += "Most common colors: \(context.topColors.joined(separator: ", "))\n"
        }
        if let weather = context.currentWeather {
            prompt += "Current weather: \(weather)\n"
        }
        prompt += "Total items: \(context.totalItems)\n\n"

        // Add recent conversation context
        if let history = conversations[bot]?.suffix(6) {
            prompt += "Recent conversation:\n"
            for msg in history {
                let role = msg.role == .user ? "User" : bot.displayName
                prompt += "\(role): \(msg.content)\n"
            }
        }

        prompt += "\nUser: \(input)\n\(bot.displayName):"
        return prompt
    }

    private func callGeminiChat(prompt: String, apiKey: String) async throws -> String {
        let encodedKey = apiKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? apiKey
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(encodedKey)") else {
            throw ChatError.invalidURL
        }

        let requestBody: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 300,
                "topP": 0.9
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ChatError.apiError
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = geminiResponse.candidates?.first?.content?.parts?.first?.text else {
            throw ChatError.noResponse
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Rule-Based Fallback

    private func ruleBasedResponse(for input: String, bot: BotPersonality, context: WardrobeContext) -> String {
        let lowered = input.lowercased()

        // Common questions with bot-specific responses
        if lowered.contains("what should i wear") || lowered.contains("outfit") || lowered.contains("suggest") {
            return outfitSuggestion(bot: bot, context: context)
        }

        if lowered.contains("color") || lowered.contains("match") || lowered.contains("pair") {
            return colorAdvice(bot: bot, context: context)
        }

        if lowered.contains("capsule") || lowered.contains("essential") || lowered.contains("basic") {
            return capsuleAdvice(bot: bot, context: context)
        }

        if lowered.contains("donate") || lowered.contains("get rid") || lowered.contains("declutter") {
            return declutterAdvice(bot: bot, context: context)
        }

        if lowered.contains("trend") || lowered.contains("style") || lowered.contains("fashion") {
            return styleAdvice(bot: bot, context: context)
        }

        if lowered.contains("hello") || lowered.contains("hi") || lowered.contains("hey") {
            return greeting(bot: bot, context: context)
        }

        // Default response
        return defaultResponse(bot: bot)
    }

    private func greeting(bot: BotPersonality, context: WardrobeContext) -> String {
        switch bot {
        case .stylist:
            return "Hey there! I'm your Style Advisor. With \(context.totalItems) items in your closet, we've got plenty to work with. What are you dressing for today?"
        case .minimalist:
            return "Hello! I'm here to help you build a focused, versatile wardrobe. You currently have \(context.totalItems) pieces — let's make sure each one earns its place."
        case .trendy:
            return "Hey! Ready to look amazing? I can help you style your \(context.totalItems) pieces in fresh, on-trend ways. What's the occasion?"
        case .sustainable:
            return "Hi! Love that you're thinking about sustainable style. With \(context.totalItems) items already in your closet, let's maximize what you have before buying anything new."
        case .colorExpert:
            let colors = context.topColors.prefix(3).joined(separator: ", ")
            return "Hello! I see you gravitate toward \(colors.isEmpty ? "various colors" : colors). Let's explore what color combinations will make your outfits pop!"
        }
    }

    private func outfitSuggestion(bot: BotPersonality, context: WardrobeContext) -> String {
        switch bot {
        case .stylist:
            return "Based on your wardrobe, I'd suggest building around your most-worn pieces. Check the Today tab for weather-appropriate suggestions — I've helped curate those! For something special, try pairing unexpected categories together."
        case .minimalist:
            return "A great outfit starts with a neutral base. Pick your most versatile bottom, add a simple top, and let one statement piece do the talking. Quality basics are the foundation of every good capsule wardrobe."
        case .trendy:
            return "Try mixing textures! Layer a structured piece over something relaxed — contrast is everything right now. Tonal dressing (head-to-toe in one color family) is also a major trend worth trying."
        case .sustainable:
            return "Before reaching for something new, challenge yourself: can you create 3 different outfits with the same top? The most sustainable outfit is one you already own. Try the Builder to discover new combinations!"
        case .colorExpert:
            let colors = context.topColors
            if colors.count >= 2 {
                return "Your \(colors[0]) pieces would pair beautifully with your \(colors[1]) items — that's a great complementary combination. For a bolder look, try monochromatic styling with different shades of one color."
            }
            return "Start with a neutral base and add one pop of color. The easiest way to look polished is sticking to 2-3 colors per outfit maximum."
        }
    }

    private func colorAdvice(bot: BotPersonality, context: WardrobeContext) -> String {
        let colors = context.topColors
        switch bot {
        case .colorExpert:
            if !colors.isEmpty {
                return "Looking at your wardrobe, you have a lot of \(colors.joined(separator: " and ")). These work well with: earth tones for warmth, navy for sophistication, or white for a clean contrast. Avoid pairing more than 3 colors in one outfit."
            }
            return "The key color rules: complementary colors (opposites on the wheel) create energy, analogous colors (neighbors) create harmony. Neutrals are your best friends for tying everything together."
        default:
            return "Great question about colors! I'd recommend checking with the Color Expert bot for detailed color theory advice. Generally, stick to 2-3 colors per outfit and use neutrals as your base."
        }
    }

    private func capsuleAdvice(bot: BotPersonality, context: WardrobeContext) -> String {
        switch bot {
        case .minimalist:
            let ideal = 37
            let current = context.totalItems
            if current > ideal {
                return "A classic capsule wardrobe has around 37 pieces. You have \(current) — that's \(current - ideal) items over. Start by identifying pieces you haven't worn in 3+ months. Those are candidates for donation."
            }
            return "You're at \(current) items — that's a great capsule wardrobe size! Focus on making sure everything mixes and matches. Each piece should create at least 3 different outfits."
        default:
            return "Capsule wardrobes focus on versatile, mix-and-match pieces. Start with 5 tops, 4 bottoms, 2 outerwear pieces, and 3 shoes — that gives you 60+ outfit combinations!"
        }
    }

    private func declutterAdvice(bot: BotPersonality, context: WardrobeContext) -> String {
        switch bot {
        case .sustainable:
            return "Before donating, consider: can it be mended, dyed, or restyled? If you truly don't wear it, donate to local shelters or textile recycling — never throw clothes in the trash. Apps like ThredUp or Poshmark can give items a second life."
        case .minimalist:
            return "Use the 'worn in the last 6 months' rule. If you haven't worn it and it's not for a specific seasonal event, it's taking space from pieces you love. Be honest — does it spark joy and fit well?"
        default:
            return "When decluttering, sort into: keep, donate, repair, and recycle. Focus on fit and how the item makes you feel. Your wardrobe should make getting dressed easy, not stressful."
        }
    }

    private func styleAdvice(bot: BotPersonality, context: WardrobeContext) -> String {
        switch bot {
        case .trendy:
            return "Right now, oversized blazers, wide-leg pants, and quiet luxury are trending. The good news? You can achieve most trends by styling what you already own differently — cuff your jeans, belt a blazer, or layer a tee under a button-down."
        case .stylist:
            return "Your personal style is more important than any trend. Focus on silhouettes that flatter your body, colors that complement your complexion, and fabrics that feel good. Confidence is the best accessory!"
        default:
            return "Style is personal — wear what makes you feel confident. Use the Builder to experiment with new combinations, and save your favorites to the Lookbook for easy reference."
        }
    }

    private func defaultResponse(bot: BotPersonality) -> String {
        switch bot {
        case .stylist: return "I can help with outfit suggestions, styling tips, and wardrobe advice! Try asking 'What should I wear today?' or 'Help me style my blazer.'"
        case .minimalist: return "I can help with capsule wardrobe building, decluttering, and finding versatile pieces. Ask me 'What are my essentials?' or 'Help me downsize.'"
        case .trendy: return "I can help with current trends, creative styling, and making your wardrobe feel fresh! Ask 'What's trending?' or 'How can I style this differently?'"
        case .sustainable: return "I can help with eco-friendly fashion, cost-per-wear analysis, and mindful shopping. Ask 'How can I wear this more?' or 'Should I buy this?'"
        case .colorExpert: return "I can help with color matching, palette building, and understanding what colors suit you. Ask 'What colors go together?' or 'Analyze my color palette.'"
        }
    }
}

enum ChatError: Error {
    case invalidURL
    case apiError
    case noResponse
}

// MARK: - Wardrobe Context

struct WardrobeContext {
    let totalItems: Int
    let categoryCounts: [(String, Int)]
    let topColors: [String]
    let currentWeather: String?

    static func build(from items: [WardrobeItem], weather: WeatherData?) -> WardrobeContext {
        let counts = Dictionary(grouping: items) { $0.category.displayName }
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }

        let colorFreq = Dictionary(grouping: items) { $0.primaryColor.lowercased() }
            .map { ($0.key.capitalized, $0.value.count) }
            .sorted { $0.1 > $1.1 }
        let topColors = Array(colorFreq.prefix(5).map(\.0))

        let weatherStr: String?
        if let w = weather {
            weatherStr = "\(w.conditionDescription), \(w.temperatureF)°F"
        } else {
            weatherStr = nil
        }

        return WardrobeContext(
            totalItems: items.count,
            categoryCounts: counts,
            topColors: topColors,
            currentWeather: weatherStr
        )
    }
}
