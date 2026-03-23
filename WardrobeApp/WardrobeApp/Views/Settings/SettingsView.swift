import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @StateObject private var store = StoreKitService()

    @EnvironmentObject private var authService: AuthService

    @State private var showDeleteConfirmation = false
    @State private var showStyleBaseline = false
    @State private var showWalkthrough = false
    @State private var showAvatarRetake = false
    @State private var isRetagging = false
    @State private var retagProgress = 0
    @State private var retagTotal = 0

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            List {
                userAccountSection
                accountSection
                avatarSection
                notificationSection
                suggestionSection
                tryOnSection
                styleSection
                helpSection
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
            .fullScreenCover(isPresented: $showWalkthrough) {
                WalkthroughView(isPresented: $showWalkthrough)
            }
            .sheet(isPresented: $showAvatarRetake) {
                NavigationStack {
                    AvatarSetupScreen(onComplete: { showAvatarRetake = false })
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Cancel") { showAvatarRetake = false }
                            }
                        }
                }
            }
        }
    }

    // MARK: - Preset Helpers

    private func weatherPresetButton(_ label: String, value: Float, profile: UserProfile) -> some View {
        let isSelected = abs(profile.weatherSensitivity - value) < 0.15
        return Button {
            profile.weatherSensitivity = value
            Haptic.selection()
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : .ultraThinMaterial)
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: DS.radiusSM))
        }
        .buttonStyle(.plain)
    }

    private func rewearPresetButton(_ label: String, value: Int, profile: UserProfile) -> some View {
        let isSelected = profile.reWearGapDays == value
        return Button {
            profile.reWearGapDays = value
            Haptic.selection()
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : .ultraThinMaterial)
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - User Account

    private var userAccountSection: some View {
        Section {
            if authService.isSignedIn, let user = authService.currentUser {
                HStack(spacing: DS.spacingMD) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Text(user.initials)
                            .font(.headline)
                            .foregroundStyle(.accent)
                    }

                    VStack(alignment: .leading, spacing: DS.spacingXS) {
                        Text(user.displayName)
                            .font(.headline)
                        if let email = user.email {
                            Text(email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button("Sign Out", role: .destructive) {
                    authService.signOut()
                }
            } else {
                VStack(alignment: .leading, spacing: DS.spacingSM) {
                    Text("Sign in to sync across devices")
                        .font(.subheadline)
                    Text("Your data is always stored locally. Sign in to back up with iCloud.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                SignInWithAppleButton()
            }
        }
        .listRowBackground(Color(.systemBackground).opacity(0.5))
    }

    // MARK: - Data Management

    private var accountSection: some View {
        Section("Data") {
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
                AppLog.ui.info("Settings: retake avatar photos")
                showAvatarRetake = true
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
        Section {
            if let profile {
                VStack(alignment: .leading, spacing: DS.spacingSM) {
                    Text("How much should weather affect suggestions?")
                        .font(.subheadline)
                    HStack(spacing: DS.spacingSM) {
                        weatherPresetButton("Low", value: 0.2, profile: profile)
                        weatherPresetButton("Medium", value: 0.5, profile: profile)
                        weatherPresetButton("High", value: 0.9, profile: profile)
                    }
                    Text("Higher = more seasonal outfits")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                VStack(alignment: .leading, spacing: DS.spacingSM) {
                    Text("Days before re-suggesting an outfit")
                        .font(.subheadline)
                    HStack(spacing: DS.spacingSM) {
                        rewearPresetButton("3 days", value: 3, profile: profile)
                        rewearPresetButton("7 days", value: 7, profile: profile)
                        rewearPresetButton("14 days", value: 14, profile: profile)
                        rewearPresetButton("21 days", value: 21, profile: profile)
                    }
                    Text("Shorter = more outfit repeats; longer = more variety")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
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

    // MARK: - Help & Tutorial

    private var helpSection: some View {
        Section("Help") {
            Button {
                showWalkthrough = true
            } label: {
                Label("App Tutorial", systemImage: "questionmark.circle")
            }

            NavigationLink {
                TipsView()
            } label: {
                Label("Tips & Tricks", systemImage: "lightbulb")
            }
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
        AppLog.data.info("Starting data export")
        let descriptor = FetchDescriptor<WardrobeItem>()
        guard let items = try? modelContext.fetch(descriptor) else {
            AppLog.data.error("Export: failed to fetch items")
            return
        }

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

        do {
            let data = try encoder.encode(exportItems)
            let url = FileStorage.itemPhotosDirectory
                .deletingLastPathComponent()
                .appendingPathComponent("wardrobe_export.json")
            try data.write(to: url)
            AppLog.data.info("Export successful: \(items.count) items to \(url.lastPathComponent)")
            Haptic.success()
        } catch {
            AppLog.data.error("Export failed: \(error.localizedDescription)")
        }
    }

    private func deleteAllData() {
        AppLog.data.warning("Deleting all user data")
        profile?.cleanupAllPhotos()
        do {
            try modelContext.delete(model: WardrobeItem.self)
            try modelContext.delete(model: Outfit.self)
            try modelContext.delete(model: PackingTrip.self)
            try modelContext.delete(model: UserProfile.self)
            AppLog.data.info("All model data deleted")
        } catch {
            AppLog.data.error("Failed to delete model data: \(error.localizedDescription)")
        }
        ImageCache.shared.clearAll()
        NotificationService.shared.cancelAll()
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        AppLog.data.info("All data deletion complete")
        Haptic.medium()
    }

    private func retagAllItems() {
        AppLog.closet.info("Starting retag of all items")
        isRetagging = true
        let descriptor = FetchDescriptor<WardrobeItem>()
        guard let items = try? modelContext.fetch(descriptor) else {
            AppLog.closet.error("Retag: failed to fetch items")
            isRetagging = false
            return
        }

        retagTotal = items.count
        retagProgress = 0

        Task {
            let gemini = GeminiVisionService()
            var successCount = 0
            var failCount = 0

            for (i, item) in items.enumerated() {
                guard let image = ImageCache.shared.load(from: item.photoURL) else {
                    AppLog.closet.debug("Retag: skipping item \(i+1) — no image")
                    failCount += 1
                    continue
                }

                do {
                    let result = try await gemini.tagSingleItem(image: image)
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
                    successCount += 1
                } catch {
                    AppLog.closet.error("Retag: failed for item \(i+1): \(error.localizedDescription)")
                    failCount += 1
                }

                // Batch save every 10 items
                if (i + 1) % 10 == 0 {
                    await MainActor.run {
                        do { try modelContext.save() } catch {
                            AppLog.data.error("Retag batch save failed at item \(i+1): \(error.localizedDescription)")
                        }
                    }
                }
            }

            AppLog.closet.info("Retag completed: \(successCount) success, \(failCount) failed")
            await MainActor.run {
                do { try modelContext.save() } catch {
                    AppLog.data.error("Retag final save failed: \(error.localizedDescription)")
                }
                isRetagging = false
                Haptic.success()
            }
        }
    }
}
