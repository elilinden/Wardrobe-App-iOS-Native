import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(filter: #Predicate<WardrobeItem> { !$0.isWishlist }) private var items: [WardrobeItem]
    @Query private var outfits: [Outfit]
    @Query private var profiles: [UserProfile]

    @StateObject private var weatherService = WeatherService()
    @StateObject private var calendarService = CalendarService()

    @State private var selectedOccasion: Occasion?
    @State private var selectedMood: Mood?
    @State private var suggestions: [OutfitSuggestion] = []
    @State private var showSettings = false
    @State private var toastMessage: ToastMessage?

    private let engine = SuggestionEngine()
    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.spacingLG) {
                    dateHeader
                    weatherCard
                    calendarChips
                    filterRow
                    suggestionsSection
                }
                .padding(DS.spacingLG)
            }
            .background { MeshGradientBackground() }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .toast($toastMessage)
            .onAppear {
                weatherService.requestLocation()
                Task { await calendarService.requestAccess() }
                generateSuggestions()
            }
            .onChange(of: selectedOccasion) { _, _ in generateSuggestions() }
            .onChange(of: selectedMood) { _, _ in generateSuggestions() }
        }
    }

    // MARK: - Date

    private var dateHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: DS.spacingXS) {
                Text(Date(), format: .dateTime.weekday(.wide))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(Date(), format: .dateTime.month(.wide).day())
                    .font(.title.weight(.bold))
            }
            Spacer()
        }
    }

    // MARK: - Weather

    @ViewBuilder
    private var weatherCard: some View {
        if let weather = weatherService.currentWeather {
            HStack(spacing: DS.spacingMD) {
                Image(systemName: weather.conditionSymbol)
                    .font(.largeTitle)
                    .symbolRenderingMode(.multicolor)

                VStack(alignment: .leading, spacing: DS.spacingXS) {
                    Text("\(Int(weather.currentTemp))°F")
                        .font(.title2.weight(.semibold))
                    Text(weather.conditionDescription.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: DS.spacingXS) {
                    Label("\(Int(weather.highTemp))°", systemImage: "arrow.up")
                        .font(.caption.weight(.medium))
                    Label("\(Int(weather.lowTemp))°", systemImage: "arrow.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .glassCard()
        }
    }

    // MARK: - Calendar

    @ViewBuilder
    private var calendarChips: some View {
        if !calendarService.todayEvents.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.spacingSM) {
                    ForEach(calendarService.todayEvents) { event in
                        HStack(spacing: DS.spacingXS) {
                            Circle()
                                .fill(event.isWorkRelated ? Color.blue : Color.green)
                                .frame(width: 6, height: 6)
                            Text(event.chipLabel)
                                .font(.caption)
                        }
                        .glassPill()
                    }
                }
            }
        }
    }

    // MARK: - Filters

    private var filterRow: some View {
        VStack(spacing: DS.spacingSM) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.spacingSM) {
                    ForEach(Occasion.allCases, id: \.self) { occ in
                        GlassChip(
                            title: occ.displayName,
                            isSelected: selectedOccasion == occ
                        ) {
                            selectedOccasion = selectedOccasion == occ ? nil : occ
                        }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.spacingSM) {
                    ForEach(Mood.allCases, id: \.self) { mood in
                        GlassChip(
                            title: mood.displayName,
                            isSelected: selectedMood == mood
                        ) {
                            selectedMood = selectedMood == mood ? nil : mood
                        }
                    }
                }
            }
        }
    }

    // MARK: - Suggestions

    @ViewBuilder
    private var suggestionsSection: some View {
        if items.count < 3 {
            VStack(spacing: DS.spacingLG) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 120, height: 120)
                    Image(systemName: "sun.max")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: DS.spacingSM) {
                    Text("Add \(3 - items.count) more item\(items.count == 2 ? "" : "s") to get suggestions")
                        .font(.title3.weight(.semibold))

                    // Progress bar
                    HStack(spacing: DS.spacingXS) {
                        ForEach(0..<3, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(i < items.count ? Color.accentColor : Color.primary.opacity(0.1))
                                .frame(height: 6)
                        }
                    }
                    .padding(.horizontal, 60)

                    Text("\(items.count) of 3 items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    appState.selectedTab = 0 // Go to Closet
                } label: {
                    Label("Go to Closet", systemImage: "tshirt")
                }
                .buttonStyle(GlassButtonStyle())
                .padding(.horizontal, 60)

                Spacer()
            }
        } else if suggestions.isEmpty {
            GlassProgressView(title: "Generating suggestions...")
        } else {
            ForEach(suggestions) { suggestion in
                SuggestionCardView(
                    suggestion: suggestion,
                    onThumbsUp: { thumbsUp(suggestion) },
                    onThumbsDown: { thumbsDown(suggestion) },
                    onSave: { save(suggestion) }
                )
            }
        }
    }

    // MARK: - Logic

    private func generateSuggestions() {
        guard items.count >= 3 else { return }

        suggestions = engine.generateSuggestions(
            allItems: items,
            weather: weatherService.currentWeather,
            events: calendarService.todayEvents,
            occasion: selectedOccasion,
            mood: selectedMood,
            recentOutfits: outfits,
            thumbsDownHistory: profile?.thumbsDownHistory ?? [],
            reWearGapDays: profile?.reWearGapDays ?? DS.defaultReWearGapDays,
            weatherSensitivity: profile?.weatherSensitivity ?? 0.5
        )
    }

    private func thumbsUp(_ s: OutfitSuggestion) {
        AppLog.suggestions.info("Thumbs up on suggestion with \(s.items.count) items")
        Haptic.light()
        toastMessage = .success("Noted! We'll suggest more like this")
    }

    private func thumbsDown(_ s: OutfitSuggestion) {
        AppLog.suggestions.info("Thumbs down on suggestion with \(s.items.count) items")
        profile?.addThumbsDown(itemIDs: Set(s.items.map(\.id)))
        do {
            try modelContext.save()
        } catch {
            AppLog.data.error("Failed to save thumbs-down: \(error.localizedDescription)")
        }
        toastMessage = .info("Got it — we'll avoid this combo")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation { generateSuggestions() }
        }
        Haptic.light()
    }

    private func save(_ s: OutfitSuggestion) {
        let outfit = Outfit(itemIDs: s.items.map(\.id), occasion: selectedOccasion)
        modelContext.insert(outfit)
        do {
            try modelContext.save()
            AppLog.outfit.info("Outfit saved from Today with \(s.items.count) items")
        } catch {
            AppLog.data.error("Failed to save outfit: \(error.localizedDescription)")
        }
        toastMessage = .success("Outfit saved to Lookbook")
        Haptic.success()
    }
}

// MARK: - Suggestion Card

struct SuggestionCardView: View {
    let suggestion: OutfitSuggestion
    let onThumbsUp: () -> Void
    let onThumbsDown: () -> Void
    let onSave: () -> Void
    @State private var showTryOn = false

    var body: some View {
        VStack(spacing: DS.spacingMD) {
            // Thumbs
            HStack {
                Spacer()
                Button(action: onThumbsUp) {
                    Image(systemName: "hand.thumbsup")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                Button(action: onThumbsDown) {
                    Image(systemName: "hand.thumbsdown")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            // Items
            HStack(spacing: DS.spacingSM) {
                ForEach(suggestion.items, id: \.id) { item in
                    VStack(spacing: DS.spacingXS) {
                        ItemThumbnail(item: item, showConditionBadge: false)
                            .aspectRatio(0.75, contentMode: .fit)
                        Text(item.displayName)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Reason
            Text(suggestion.primaryReason)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Actions
            HStack(spacing: DS.spacingMD) {
                Button { showTryOn = true } label: {
                    Label("Try On", systemImage: "person.fill")
                }
                .buttonStyle(GlassButtonStyle())

                Button(action: onSave) {
                    Label("Save", systemImage: "bookmark")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .glassCard()
        .sheet(isPresented: $showTryOn) {
            TryOnView(items: suggestion.items)
        }
    }
}
