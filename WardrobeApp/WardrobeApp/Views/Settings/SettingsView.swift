import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @StateObject private var store = StoreKitService()

    @State private var showDeleteConfirmation = false
    @State private var showStyleBaseline = false
    @State private var isRetagging = false
    @State private var retagProgress = 0
    @State private var retagTotal = 0

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            List {
                accountSection
                avatarSection
                notificationSection
                suggestionSection
                tryOnSection
                styleSection
                privacySection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background { MeshGradientBackground() }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete All Data?", isPresented: $showDeleteConfirmation) {
                Button("Delete Everything", role: .destructive) { deleteAllData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes all items, outfits, and settings. This cannot be undone.")
            }
            .sheet(isPresented: $showStyleBaseline) {
                NavigationStack {
                    StyleBaselineScreen()
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Cancel") { showStyleBaseline = false }
                            }
                        }
                }
            }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        Section("Account") {
            if let profile {
                Toggle("iCloud Sync", isOn: Binding(
                    get: { profile.iCloudSyncEnabled },
                    set: { profile.iCloudSyncEnabled = $0 }
                ))
            }

            Button("Export My Data") { exportData() }

            Button("Delete All Data", role: .destructive) {
                showDeleteConfirmation = true
            }
        }
        .listRowBackground(Color(.systemBackground).opacity(0.5))
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        Section("Avatar") {
            if let profile, profile.hasAvatarPhotos {
                HStack(spacing: DS.spacingSM) {
                    ForEach(profile.avatarPhotoURLs, id: \.absoluteString) { url in
                        if let img = ImageCache.shared.load(from: url) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: DS.radiusSM))
                        }
                    }
                }
            }
            Button("Retake Avatar Photos") {
                // Would relaunch avatar setup
            }
        }
        .listRowBackground(Color(.systemBackground).opacity(0.5))
    }

    // MARK: - Notifications

    private var notificationSection: some View {
        Section("Notifications") {
            if let profile {
                Toggle("Morning Suggestion", isOn: Binding(
                    get: { profile.notificationsEnabled },
                    set: { newVal in
                        profile.notificationsEnabled = newVal
                        if newVal {
                            Task {
                                let granted = await NotificationService.shared.requestPermission()
                                if granted {
                                    NotificationService.shared.scheduleMorningSuggestion(
                                        hour: profile.notificationHour,
                                        minute: profile.notificationMinute
                                    )
                                }
                            }
                        } else {
                            NotificationService.shared.cancelMorningSuggestion()
                        }
                    }
                ))

                if profile.notificationsEnabled {
                    DatePicker(
                        "Notification Time",
                        selection: notificationTimeBinding(profile),
                        displayedComponents: .hourAndMinute
                    )
                }

                Toggle("Evening Reminder", isOn: Binding(
                    get: { profile.eveningReminderEnabled },
                    set: { newVal in
                        profile.eveningReminderEnabled = newVal
                        if newVal {
                            NotificationService.shared.scheduleEveningReminder(
                                hour: profile.eveningReminderHour,
                                minute: profile.eveningReminderMinute
                            )
                        } else {
                            NotificationService.shared.cancelEveningReminder()
                        }
                    }
                ))

                if profile.eveningReminderEnabled {
                    DatePicker(
                        "Evening Time",
                        selection: eveningTimeBinding(profile),
                        displayedComponents: .hourAndMinute
                    )
                }
            }
        }
        .listRowBackground(Color(.systemBackground).opacity(0.5))
    }

    // MARK: - Suggestions

    private var suggestionSection: some View {
        Section("Suggestions") {
            if let profile {
                VStack(alignment: .leading, spacing: DS.spacingSM) {
                    Text("Weather Sensitivity: \(Int(profile.weatherSensitivity * 100))%")
                        .font(.subheadline)
                    Slider(
                        value: Binding(
                            get: { Double(profile.weatherSensitivity) },
                            set: { profile.weatherSensitivity = Float($0) }
                        ), in: 0...1
                    )
                    .tint(.accentColor)
                }

                VStack(alignment: .leading, spacing: DS.spacingSM) {
                    Text("Re-wear Gap: \(profile.reWearGapDays) days")
                        .font(.subheadline)
                    Slider(
                        value: Binding(
                            get: { Double(profile.reWearGapDays) },
                            set: { profile.reWearGapDays = Int($0) }
                        ),
                        in: DS.reWearGapRange, step: 1
                    )
                    .tint(.accentColor)
                }

                Button {
                    retagAllItems()
                } label: {
                    if isRetagging {
                        HStack {
                            ProgressView()
                            Text("Re-tagging \(retagProgress)/\(retagTotal)...")
                        }
                    } else {
                        Text("Re-tag All Items")
                    }
                }
                .disabled(isRetagging)
            }
        }
        .listRowBackground(Color(.systemBackground).opacity(0.5))
    }

    // MARK: - Try-On

    private var tryOnSection: some View {
        Section("Try-On") {
            if let profile {
                HStack {
                    Text("Monthly Renders")
                    Spacer()
                    Text(profile.rendersUsedText)
                        .foregroundStyle(profile.hasUnlimitedRenders ? .green : .secondary)
                }

                if !profile.hasUnlimitedRenders && !store.hasUnlimitedRenders {
                    Button {
                        Task {
                            try? await store.purchaseUnlimitedRenders()
                            if store.hasUnlimitedRenders {
                                profile.hasUnlimitedRenders = true
                                try? modelContext.save()
                            }
                        }
                    } label: {
                        HStack {
                            Text("Upgrade to Unlimited")
                            Spacer()
                            Text("$2.99").foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listRowBackground(Color(.systemBackground).opacity(0.5))
    }

    // MARK: - Style

    private var styleSection: some View {
        Section("Style Baseline") {
            Button("Re-run Style Questions") { showStyleBaseline = true }
        }
        .listRowBackground(Color(.systemBackground).opacity(0.5))
    }

    // MARK: - Privacy

    private var privacySection: some View {
        Section("Privacy") {
            VStack(alignment: .leading, spacing: DS.spacingSM) {
                Text("Your Data Privacy").font(.subheadline.weight(.semibold))
                Text("""
                All clothing photos, outfits, and preferences are stored on your device and \
                your personal iCloud. No data is stored on our servers.

                API calls are made only for: auto-tagging items (Gemini Vision), \
                try-on renders (Pixelcut), and weather data (Apple WeatherKit).

                Avatar photos are sent temporarily during renders and never stored externally. \
                Zero analytics or tracking.
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .listRowBackground(Color(.systemBackground).opacity(0.5))
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0").foregroundStyle(.secondary)
            }
            Link("Rate This App", destination: URL(string: "https://apps.apple.com")!)
            Link("Contact Support", destination: URL(string: "mailto:support@wardrobeapp.com")!)
        }
        .listRowBackground(Color(.systemBackground).opacity(0.5))
    }

    // MARK: - Helpers

    private func notificationTimeBinding(_ profile: UserProfile) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: profile.notificationHour, minute: profile.notificationMinute)) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                profile.notificationHour = c.hour ?? 7
                profile.notificationMinute = c.minute ?? 0
                NotificationService.shared.scheduleMorningSuggestion(
                    hour: profile.notificationHour, minute: profile.notificationMinute
                )
            }
        )
    }

    private func eveningTimeBinding(_ profile: UserProfile) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: profile.eveningReminderHour, minute: profile.eveningReminderMinute)) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                profile.eveningReminderHour = c.hour ?? 21
                profile.eveningReminderMinute = c.minute ?? 0
                NotificationService.shared.scheduleEveningReminder(
                    hour: profile.eveningReminderHour, minute: profile.eveningReminderMinute
                )
            }
        )
    }

    private func exportData() {
        let descriptor = FetchDescriptor<WardrobeItem>()
        guard let items = try? modelContext.fetch(descriptor) else { return }

        struct Export: Codable {
            let name: String?; let brand: String?; let category: String
            let subcategory: String; let primaryColor: String; let secondaryColor: String?
            let pattern: String; let material: String; let formality: String
            let seasons: [String]; let purchasePrice: Double?; let dateAdded: Date
            let condition: String; let timesWorn: Int
        }

        let exportItems = items.map {
            Export(
                name: $0.name, brand: $0.brand, category: $0.categoryRaw,
                subcategory: $0.subcategory, primaryColor: $0.primaryColor,
                secondaryColor: $0.secondaryColor, pattern: $0.patternRaw,
                material: $0.materialEstimateRaw, formality: $0.formalityRaw,
                seasons: $0.seasonsRaw, purchasePrice: $0.purchasePrice,
                dateAdded: $0.dateAdded, condition: $0.conditionRaw,
                timesWorn: $0.timesWorn
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(exportItems) {
            let url = FileStorage.itemPhotosDirectory
                .deletingLastPathComponent()
                .appendingPathComponent("wardrobe_export.json")
            try? data.write(to: url)
            Haptic.success()
        }
    }

    private func deleteAllData() {
        profile?.cleanupAllPhotos()
        try? modelContext.delete(model: WardrobeItem.self)
        try? modelContext.delete(model: Outfit.self)
        try? modelContext.delete(model: PackingTrip.self)
        try? modelContext.delete(model: UserProfile.self)
        ImageCache.shared.clearAll()
        NotificationService.shared.cancelAll()
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        Haptic.medium()
    }

    private func retagAllItems() {
        isRetagging = true
        let descriptor = FetchDescriptor<WardrobeItem>()
        guard let items = try? modelContext.fetch(descriptor) else {
            isRetagging = false
            return
        }

        retagTotal = items.count
        retagProgress = 0

        Task {
            let gemini = GeminiVisionService()
            for (i, item) in items.enumerated() {
                guard let image = ImageCache.shared.load(from: item.photoURL) else { continue }

                if let result = try? await gemini.tagSingleItem(image: image) {
                    await MainActor.run {
                        item.category = Category(rawValue: result.category) ?? item.category
                        item.subcategory = result.subcategory
                        item.primaryColor = result.primaryColor
                        item.secondaryColor = result.secondaryColor
                        item.pattern = Pattern(rawValue: result.pattern) ?? item.pattern
                        item.materialEstimate = Material(rawValue: result.materialEstimate) ?? item.materialEstimate
                        item.formality = Formality(rawValue: result.formality) ?? item.formality
                        item.seasons = result.season.compactMap { Season(rawValue: $0) }
                        retagProgress = i + 1
                    }
                }

                // Batch save every 10 items
                if (i + 1) % 10 == 0 {
                    await MainActor.run { try? modelContext.save() }
                }
            }

            await MainActor.run {
                try? modelContext.save()
                isRetagging = false
                Haptic.success()
            }
        }
    }
}
