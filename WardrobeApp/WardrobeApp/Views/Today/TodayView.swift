import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [WardrobeItem]
    @Query private var outfits: [Outfit]
    @Query private var profiles: [UserProfile]

    @StateObject private var weatherService = WeatherService()
    @StateObject private var calendarService = CalendarService()

    @State private var selectedOccasion: Occasion?
    @State private var selectedMood: Mood?
    @State private var suggestions: [OutfitSuggestion] = []
    @State private var showSettings = false
    @State private var thumbsDownHistory: Set<Set<UUID>> = []

    private let suggestionEngine = SuggestionEngine()

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Date
                    dateHeader

                    // Weather
                    if let weather = weatherService.currentWeather {
                        weatherStrip(weather)
                    }

                    // Calendar events
                    if !calendarService.todayEvents.isEmpty {
                        calendarStrip
                    }

                    // Occasion filters
                    filterChips

                    // Suggestions
                    if items.filter({ !$0.isWishlist }).count < 3 {
                        emptyState
                    } else if suggestions.isEmpty {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Generating suggestions...")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 40)
                    } else {
                        ForEach(suggestions) { suggestion in
                            SuggestionCard(
                                suggestion: suggestion,
                                onThumbsUp: { thumbsUp(suggestion) },
                                onThumbsDown: { thumbsDown(suggestion) },
                                onSaveToLookbook: { saveToLookbook(suggestion) }
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onAppear {
                weatherService.requestLocation()
                Task { await calendarService.requestAccess() }
                generateSuggestions()
            }
            .onChange(of: selectedOccasion) { _, _ in generateSuggestions() }
            .onChange(of: selectedMood) { _, _ in generateSuggestions() }
        }
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return Text(formatter.string(from: Date()))
            .font(.title2)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Weather Strip

    private func weatherStrip(_ weather: WeatherInfo) -> some View {
        HStack(spacing: 12) {
            Image(systemName: weather.conditionSymbol)
                .font(.title2)
                .symbolRenderingMode(.multicolor)

            VStack(alignment: .leading) {
                Text("\(Int(weather.currentTemp))°F")
                    .font(.headline)
                Text(weather.conditionDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("H: \(Int(weather.highTemp))°")
                    .font(.caption)
                Text("L: \(Int(weather.lowTemp))°")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Calendar Strip

    private var calendarStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(calendarService.todayEvents) { event in
                    Text(event.chipLabel)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(event.isWorkRelated ? Color.blue.opacity(0.15) : Color(.systemGray5))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Occasion.allCases, id: \.self) { occasion in
                        FilterChip(
                            title: occasion.displayName,
                            isSelected: selectedOccasion == occasion,
                            onTap: {
                                selectedOccasion = selectedOccasion == occasion ? nil : occasion
                            }
                        )
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Mood.allCases, id: \.self) { mood in
                        FilterChip(
                            title: mood.displayName,
                            isSelected: selectedMood == mood,
                            onTap: {
                                selectedMood = selectedMood == mood ? nil : mood
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sun.max")
                .font(.system(size: 60))
                .foregroundStyle(.quaternary)
            Text("Add some clothes first,\nthen we'll suggest outfits.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, 40)
    }

    // MARK: - Logic

    private func generateSuggestions() {
        let closetItems = items.filter { !$0.isWishlist }
        guard closetItems.count >= 3 else { return }

        suggestions = suggestionEngine.generateSuggestions(
            allItems: closetItems,
            weather: weatherService.currentWeather,
            events: calendarService.todayEvents,
            occasion: selectedOccasion,
            mood: selectedMood,
            recentOutfits: outfits,
            thumbsDownHistory: thumbsDownHistory,
            reWearGapDays: profile?.reWearGapDays ?? 14,
            weatherSensitivity: profile?.weatherSensitivity ?? 0.5
        )
    }

    private func thumbsUp(_ suggestion: OutfitSuggestion) {
        // Positive feedback - boost these items in future
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func thumbsDown(_ suggestion: OutfitSuggestion) {
        let itemIDs = Set(suggestion.items.map(\.id))
        thumbsDownHistory.insert(itemIDs)
        generateSuggestions()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func saveToLookbook(_ suggestion: OutfitSuggestion) {
        let outfit = Outfit(
            itemIDs: suggestion.items.map(\.id),
            occasion: selectedOccasion
        )
        modelContext.insert(outfit)
        try? modelContext.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

struct SuggestionCard: View {
    let suggestion: OutfitSuggestion
    let onThumbsUp: () -> Void
    let onThumbsDown: () -> Void
    let onSaveToLookbook: () -> Void

    @State private var showTryOn = false

    var body: some View {
        VStack(spacing: 12) {
            // Thumbs up/down
            HStack {
                Spacer()
                Button(action: onThumbsUp) {
                    Image(systemName: "hand.thumbsup")
                        .foregroundStyle(.green)
                }
                Button(action: onThumbsDown) {
                    Image(systemName: "hand.thumbsdown")
                        .foregroundStyle(.red)
                }
            }

            // Item collage
            HStack(spacing: 8) {
                ForEach(suggestion.items, id: \.id) { item in
                    ItemThumbnail(item: item, size: nil)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(0.75, contentMode: .fit)
                }
            }

            // Item names
            HStack {
                ForEach(suggestion.items, id: \.id) { item in
                    Text(item.name ?? item.subcategory.capitalized)
                        .font(.caption)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
            }

            // Reason
            Text(suggestion.reason)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Actions
            HStack(spacing: 12) {
                Button {
                    showTryOn = true
                } label: {
                    Label("Try On", systemImage: "person.fill")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: onSaveToLookbook) {
                    Label("Save", systemImage: "bookmark")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showTryOn) {
            TryOnView(items: suggestion.items)
        }
    }
}
