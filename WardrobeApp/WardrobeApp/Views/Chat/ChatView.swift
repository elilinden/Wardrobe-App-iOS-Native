import SwiftUI
import SwiftData

struct ChatView: View {
    @Query(filter: #Predicate<WardrobeItem> { !$0.isWishlist }) private var items: [WardrobeItem]
    @StateObject private var chatService = ChatService()
    @StateObject private var weatherService = WeatherService()

    @State private var selectedBot: BotPersonality?

    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground()

                if let bot = selectedBot {
                    ChatConversationView(
                        bot: bot,
                        chatService: chatService,
                        items: items,
                        weather: weatherService.currentWeather,
                        onBack: { selectedBot = nil }
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    botSelector
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35), value: selectedBot)
            .navigationTitle(selectedBot?.displayName ?? "AI Assistants")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Bot Selector

    private var botSelector: some View {
        ScrollView {
            VStack(spacing: DS.spacingMD) {
                // Header
                VStack(spacing: DS.spacingSM) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 80, height: 80)
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 32))
                            .foregroundStyle(.accent)
                            .symbolRenderingMode(.hierarchical)
                    }

                    Text("Choose Your Advisor")
                        .font(.title3.weight(.semibold))
                    Text("Each bot has a unique perspective on your wardrobe")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, DS.spacingLG)

                // Bot cards
                ForEach(BotPersonality.allCases) { bot in
                    BotCard(bot: bot, messageCount: chatService.conversations[bot]?.count ?? 0) {
                        selectedBot = bot
                        Haptic.selection()
                        AppLog.ui.info("Chat: Selected bot \(bot.displayName)")
                    }
                }
            }
            .padding(DS.spacingLG)
        }
    }
}

// MARK: - Bot Card

struct BotCard: View {
    let bot: BotPersonality
    let messageCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.spacingMD) {
                ZStack {
                    Circle()
                        .fill(bot.accentColor.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: bot.icon)
                        .font(.title2)
                        .foregroundStyle(bot.accentColor)
                }

                VStack(alignment: .leading, spacing: DS.spacingXS) {
                    Text(bot.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(bot.tagline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: DS.spacingXS) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    if messageCount > 0 {
                        Text("\(messageCount) msgs")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(DS.spacingMD)
            .glassBackground(cornerRadius: DS.radiusLG)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chat Conversation

struct ChatConversationView: View {
    let bot: BotPersonality
    @ObservedObject var chatService: ChatService
    let items: [WardrobeItem]
    let weather: WeatherData?
    let onBack: () -> Void

    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    private var messages: [ChatMessage] {
        chatService.conversations[bot] ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            // Back button & bot info
            HStack(spacing: DS.spacingMD) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.medium))
                }

                ZStack {
                    Circle()
                        .fill(bot.accentColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: bot.icon)
                        .foregroundStyle(bot.accentColor)
                }

                VStack(alignment: .leading) {
                    Text(bot.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(chatService.isTyping ? "Typing..." : "Online")
                        .font(.caption2)
                        .foregroundStyle(chatService.isTyping ? bot.accentColor : .secondary)
                }

                Spacer()

                Menu {
                    Button(role: .destructive) {
                        chatService.clearConversation(for: bot)
                    } label: {
                        Label("Clear Chat", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, DS.spacingLG)
            .padding(.vertical, DS.spacingSM)
            .glassBackground(cornerRadius: 0)

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: DS.spacingMD) {
                        // Welcome message if empty
                        if messages.isEmpty {
                            welcomeMessage
                        }

                        ForEach(messages) { message in
                            ChatBubble(message: message, bot: bot)
                                .id(message.id)
                        }

                        if chatService.isTyping {
                            TypingIndicator(bot: bot)
                                .id("typing")
                        }
                    }
                    .padding(DS.spacingLG)
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo(messages.last?.id ?? "typing", anchor: .bottom)
                    }
                }
            }

            // Quick suggestions
            if messages.count < 3 {
                quickSuggestions
            }

            // Input bar
            inputBar
        }
    }

    // MARK: - Welcome

    private var welcomeMessage: some View {
        VStack(spacing: DS.spacingMD) {
            ZStack {
                Circle()
                    .fill(bot.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: bot.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(bot.accentColor)
            }

            Text("Hi! I'm your \(bot.displayName).")
                .font(.headline)

            Text(bot.tagline)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Ask me anything about your wardrobe!")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, DS.spacingXXL)
    }

    // MARK: - Quick Suggestions

    private var quickSuggestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.spacingSM) {
                ForEach(suggestionsForBot, id: \.self) { suggestion in
                    Button {
                        sendMessage(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(bot.accentColor.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.spacingLG)
            .padding(.vertical, DS.spacingSM)
        }
    }

    private var suggestionsForBot: [String] {
        switch bot {
        case .stylist:
            return ["What should I wear today?", "Style my blazer", "Date night outfit", "Work outfit ideas"]
        case .minimalist:
            return ["Am I a minimalist?", "What are my essentials?", "Help me declutter", "Build a capsule"]
        case .trendy:
            return ["What's trending?", "Style this differently", "Layering ideas", "Weekend look"]
        case .sustainable:
            return ["Cost per wear analysis", "What can I upcycle?", "Do I need new clothes?", "Care tips"]
        case .colorExpert:
            return ["Analyze my palette", "What colors suit me?", "Fix a color clash", "Monochrome outfit"]
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: DS.spacingSM) {
            TextField("Ask \(bot.displayName)...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .onSubmit { sendIfNotEmpty() }

            Button(action: sendIfNotEmpty) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? .tertiary : bot.accentColor)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || chatService.isTyping)
        }
        .padding(.horizontal, DS.spacingLG)
        .padding(.vertical, DS.spacingMD)
        .glassBackground(cornerRadius: 0)
    }

    private func sendIfNotEmpty() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        sendMessage(trimmed)
    }

    private func sendMessage(_ text: String) {
        inputText = ""
        isInputFocused = false
        Haptic.light()

        let context = WardrobeContext.build(from: items, weather: weather)
        Task {
            await chatService.sendMessage(text, to: bot, wardrobeContext: context)
        }
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage
    let bot: BotPersonality

    var body: some View {
        HStack(alignment: .bottom, spacing: DS.spacingSM) {
            if message.role == .user {
                Spacer(minLength: 60)
            } else {
                ZStack {
                    Circle()
                        .fill(bot.accentColor.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: bot.icon)
                        .font(.caption2)
                        .foregroundStyle(bot.accentColor)
                }
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: DS.spacingXS) {
                Text(message.content)
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.role == .user
                            ? AnyShapeStyle(Color.accentColor)
                            : AnyShapeStyle(.ultraThinMaterial)
                    )
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                Text(message.timestamp, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if message.role != .user {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    let bot: BotPersonality
    @State private var dotScale: [CGFloat] = [0.5, 0.5, 0.5]

    var body: some View {
        HStack(alignment: .bottom, spacing: DS.spacingSM) {
            ZStack {
                Circle()
                    .fill(bot.accentColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: bot.icon)
                    .font(.caption2)
                    .foregroundStyle(bot.accentColor)
            }

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(.secondary)
                        .frame(width: 7, height: 7)
                        .scaleEffect(dotScale[i])
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .onAppear { animateDots() }

            Spacer(minLength: 60)
        }
    }

    private func animateDots() {
        for i in 0..<3 {
            withAnimation(
                .easeInOut(duration: 0.5)
                .repeatForever(autoreverses: true)
                .delay(Double(i) * 0.2)
            ) {
                dotScale[i] = 1.0
            }
        }
    }
}
