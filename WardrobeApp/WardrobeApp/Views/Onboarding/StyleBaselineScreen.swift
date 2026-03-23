import SwiftUI
import SwiftData

struct StyleBaselineScreen: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var onFinish: (() -> Void)? = nil

    @State private var dressesFor = "mix"
    @State private var excludedColors: Set<String> = []
    @State private var styleDescription = "classic"
    @State private var decisionTime = "under_1_min"
    @State private var morningPref = "check_manually"

    private let colorOptions = [
        "Black", "White", "Navy", "Gray", "Brown", "Beige",
        "Red", "Pink", "Orange", "Yellow", "Green", "Blue", "Purple"
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.spacingXXL) {
                ProgressDots(step: 3, totalSteps: 4)
                    .padding(.top, DS.spacingLG)

                VStack(spacing: DS.spacingSM) {
                    Text("Style Baseline")
                        .font(.title.weight(.bold))
                    Text("These help us personalize your daily suggestions")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: DS.spacingXL) {
                    questionSection("What do you mainly dress for?", hint: "We'll prioritize outfits for these occasions") {
                        GlassChipSelector(
                            options: ["Work", "Casual", "Going out", "Mix of everything"],
                            values: ["work", "casual", "going_out", "mix"],
                            selected: $dressesFor
                        )
                    }

                    questionSection("Any colors you never wear?", hint: "We'll avoid these in outfit suggestions") {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible()), count: 5),
                            spacing: DS.spacingSM
                        ) {
                            ForEach(colorOptions, id: \.self) { color in
                                ColorExcludeChip(
                                    colorName: color,
                                    isExcluded: excludedColors.contains(color)
                                ) {
                                    if excludedColors.contains(color) {
                                        excludedColors.remove(color)
                                    } else {
                                        excludedColors.insert(color)
                                    }
                                }
                            }
                        }
                    }

                    questionSection("How would you describe your style?", hint: "Shapes which items we pair together") {
                        GlassChipSelector(
                            options: ["Minimal", "Classic", "Streetwear", "Feminine", "Eclectic", "Still figuring it out"],
                            values: ["minimal", "classic", "streetwear", "feminine", "eclectic", "figuring_out"],
                            selected: $styleDescription
                        )
                    }

                    questionSection("How much time on outfit decisions?", hint: "Quick = fewer choices; exploratory = more options") {
                        GlassChipSelector(
                            options: ["Under 1 min", "A few minutes", "I like exploring"],
                            values: ["under_1_min", "few_minutes", "like_exploring"],
                            selected: $decisionTime
                        )
                    }

                    questionSection("Morning outfit suggestions?", hint: "Get a notification with today's outfit pick") {
                        GlassChipSelector(
                            options: ["Yes, notify me", "Yes, I'll check", "No thanks"],
                            values: ["notify", "check_manually", "no"],
                            selected: $morningPref
                        )
                    }
                }

                Button(action: finishOnboarding) {
                    Text("Finish Setup")
                }
                .buttonStyle(GlassButtonStyle())
                .padding(.horizontal, DS.spacingXL)
                .padding(.bottom, 50)
            }
            .padding(.horizontal, DS.spacingLG)
        }
    }

    private func questionSection<Content: View>(_ title: String, hint: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            VStack(alignment: .leading, spacing: DS.spacingXS) {
                Text(title)
                    .font(.headline)
                if let hint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            content()
        }
    }

    private func finishOnboarding() {
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = try? modelContext.fetch(descriptor).first else { return }

        profile.stylePreferences = StylePreferences(
            dressesFor: dressesFor,
            excludedColors: Array(excludedColors),
            styleDescription: styleDescription,
            decisionTime: decisionTime,
            morningNotificationPref: morningPref
        )
        profile.hasCompletedOnboarding = true
        profile.notificationsEnabled = morningPref == "notify"

        if morningPref == "notify" {
            Task {
                let granted = await NotificationService.shared.requestPermission()
                if granted {
                    NotificationService.shared.scheduleMorningSuggestion(
                        hour: profile.notificationHour,
                        minute: profile.notificationMinute
                    )
                }
            }
        }

        try? modelContext.save()

        Haptic.success()

        if let onFinish {
            onFinish() // Go to walkthrough step
        } else {
            appState.hasCompletedOnboarding = true // Direct from Settings re-run
        }
    }
}
