import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @StateObject private var storeService = StoreKitService()

    @State private var showRetakeAvatar = false
    @State private var showStyleBaseline = false
    @State private var showDeleteConfirmation = false
    @State private var showExportSuccess = false
    @State private var isRetagging = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            List {
                // Account
                Section("Account") {
                    if let profile = profile {
                        Toggle("iCloud Sync", isOn: Binding(
                            get: { profile.iCloudSyncEnabled },
                            set: { profile.iCloudSyncEnabled = $0 }
                        ))
                    }

                    Button("Export My Data") {
                        exportData()
                    }

                    Button("Delete All Data", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }

                // Avatar
                Section("Avatar") {
                    if let profile = profile, !profile.avatarPhotoFileNames.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(profile.avatarPhotoURLs, id: \.absoluteString) { url in
                                if let image = ImageService.shared.loadImage(from: url) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }

                    Button("Retake Avatar Photos") {
                        showRetakeAvatar = true
                    }
                }

                // Notifications
                Section("Notifications") {
                    if let profile = profile {
                        Toggle("Morning Outfit Suggestion", isOn: Binding(
                            get: { profile.notificationsEnabled },
                            set: { profile.notificationsEnabled = $0 }
                        ))

                        if profile.notificationsEnabled {
                            DatePicker(
                                "Notification Time",
                                selection: Binding(
                                    get: {
                                        var components = DateComponents()
                                        components.hour = profile.notificationHour
                                        components.minute = profile.notificationMinute
                                        return Calendar.current.date(from: components) ?? Date()
                                    },
                                    set: { date in
                                        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                                        profile.notificationHour = components.hour ?? 7
                                        profile.notificationMinute = components.minute ?? 0
                                    }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                        }

                        Toggle("Evening Reminder", isOn: Binding(
                            get: { profile.eveningReminderEnabled },
                            set: { profile.eveningReminderEnabled = $0 }
                        ))

                        if profile.eveningReminderEnabled {
                            DatePicker(
                                "Evening Time",
                                selection: Binding(
                                    get: {
                                        var components = DateComponents()
                                        components.hour = profile.eveningReminderHour
                                        components.minute = profile.eveningReminderMinute
                                        return Calendar.current.date(from: components) ?? Date()
                                    },
                                    set: { date in
                                        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                                        profile.eveningReminderHour = components.hour ?? 21
                                        profile.eveningReminderMinute = components.minute ?? 0
                                    }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                        }
                    }
                }

                // Suggestions
                Section("Suggestions") {
                    if let profile = profile {
                        VStack(alignment: .leading) {
                            Text("Weather Sensitivity: \(Int(profile.weatherSensitivity * 100))%")
                                .font(.subheadline)
                            Slider(value: Binding(
                                get: { Double(profile.weatherSensitivity) },
                                set: { profile.weatherSensitivity = Float($0) }
                            ), in: 0...1)
                        }

                        VStack(alignment: .leading) {
                            Text("Re-wear Gap: \(profile.reWearGapDays) days")
                                .font(.subheadline)
                            Slider(
                                value: Binding(
                                    get: { Double(profile.reWearGapDays) },
                                    set: { profile.reWearGapDays = Int($0) }
                                ),
                                in: 7...30,
                                step: 1
                            )
                        }

                        Button {
                            retagAllItems()
                        } label: {
                            if isRetagging {
                                HStack {
                                    ProgressView()
                                    Text("Re-tagging items...")
                                }
                            } else {
                                Text("Re-tag All Items")
                            }
                        }
                        .disabled(isRetagging)
                    }
                }

                // Try-On
                Section("Try-On") {
                    if let profile = profile {
                        HStack {
                            Text("Monthly Renders Used")
                            Spacer()
                            if profile.hasUnlimitedRenders {
                                Text("Unlimited")
                                    .foregroundStyle(.green)
                            } else {
                                Text("\(profile.monthlyRenderCount) of 30")
                            }
                        }

                        if !profile.hasUnlimitedRenders && !storeService.hasUnlimitedRenders {
                            Button {
                                Task {
                                    try? await storeService.purchaseUnlimitedRenders()
                                    if storeService.hasUnlimitedRenders {
                                        profile.hasUnlimitedRenders = true
                                        try? modelContext.save()
                                    }
                                }
                            } label: {
                                HStack {
                                    Text("Upgrade to Unlimited")
                                    Spacer()
                                    Text("$2.99")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                // Style Baseline
                Section("Style Baseline") {
                    Button("Re-run Style Questions") {
                        showStyleBaseline = true
                    }
                }

                // Privacy
                Section("Privacy") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Data Privacy")
                            .font(.headline)

                        Text("""
                        All your clothing photos, outfits, and preferences are stored \
                        on your device and in your personal iCloud account. No data is \
                        stored on our servers.

                        API calls are made only when:
                        - Auto-tagging a new item (Gemini Vision API)
                        - Generating a try-on render (Pixelcut API)
                        - Fetching weather data (Apple WeatherKit)

                        Your avatar photos are sent temporarily during try-on renders \
                        and are never stored on any external server.

                        We use zero analytics or tracking.
                        """)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link("Rate This App", destination: URL(string: "https://apps.apple.com")!)

                    Link("Contact Support", destination: URL(string: "mailto:support@wardrobeapp.com")!)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete All Data?", isPresented: $showDeleteConfirmation) {
                Button("Delete Everything", role: .destructive) {
                    deleteAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your clothing items, outfits, and settings. This cannot be undone.")
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

    private func exportData() {
        // Export items as JSON
        let descriptor = FetchDescriptor<WardrobeItem>()
        guard let items = try? modelContext.fetch(descriptor) else { return }

        struct ExportItem: Codable {
            let name: String?
            let brand: String?
            let category: String
            let subcategory: String
            let primaryColor: String
            let secondaryColor: String?
            let pattern: String
            let material: String
            let formality: String
            let seasons: [String]
            let purchasePrice: Double?
            let dateAdded: Date
            let condition: String
            let timesWorn: Int
        }

        let exportItems = items.map { item in
            ExportItem(
                name: item.name, brand: item.brand,
                category: item.categoryRaw, subcategory: item.subcategory,
                primaryColor: item.primaryColor, secondaryColor: item.secondaryColor,
                pattern: item.patternRaw, material: item.materialEstimateRaw,
                formality: item.formalityRaw, seasons: item.seasonsRaw,
                purchasePrice: item.purchasePrice, dateAdded: item.dateAdded,
                condition: item.conditionRaw, timesWorn: item.timesWorn
            )
        }

        if let jsonData = try? JSONEncoder().encode(exportItems) {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let exportURL = documentsPath.appendingPathComponent("wardrobe_export.json")
            try? jsonData.write(to: exportURL)
            showExportSuccess = true
        }
    }

    private func deleteAllData() {
        try? modelContext.delete(model: WardrobeItem.self)
        try? modelContext.delete(model: Outfit.self)
        try? modelContext.delete(model: PackingTrip.self)
        try? modelContext.delete(model: UserProfile.self)

        // Clean up photos
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        try? FileManager.default.removeItem(at: documentsPath.appendingPathComponent("ItemPhotos"))
        try? FileManager.default.removeItem(at: documentsPath.appendingPathComponent("AvatarPhotos"))
        try? FileManager.default.removeItem(at: documentsPath.appendingPathComponent("TryOnRenders"))

        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }

    private func retagAllItems() {
        isRetagging = true
        let descriptor = FetchDescriptor<WardrobeItem>()
        guard let items = try? modelContext.fetch(descriptor) else {
            isRetagging = false
            return
        }

        Task {
            let gemini = GeminiVisionService()
            for item in items {
                guard let image = ImageService.shared.loadImage(from: item.photoURL) else { continue }
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
                    }
                }
            }
            await MainActor.run {
                try? modelContext.save()
                isRetagging = false
            }
        }
    }
}
