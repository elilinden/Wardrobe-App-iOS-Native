import SwiftUI

struct OnboardingFlow: View {
    @State private var currentStep = 0

    var body: some View {
        NavigationStack {
            Group {
                switch currentStep {
                case 0:
                    WelcomeScreen(onContinue: { currentStep = 1 })
                case 1:
                    AvatarSetupScreen(onContinue: { currentStep = 2 })
                case 2:
                    ClosetImportScreen(onContinue: { currentStep = 3 })
                case 3:
                    StyleBaselineScreen()
                default:
                    WelcomeScreen(onContinue: { currentStep = 1 })
                }
            }
            .animation(.easeInOut, value: currentStep)
        }
    }
}

struct WelcomeScreen: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "tshirt.fill")
                .font(.system(size: 80))
                .foregroundStyle(.accent)

            VStack(spacing: 12) {
                Text("Your wardrobe, organized.\nOutfits, decided.")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Private. No subscriptions. No social feed.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button(action: onContinue) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .padding()
    }
}

struct AvatarSetupScreen: View {
    let onContinue: () -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var frontPhoto: UIImage?
    @State private var leftPhoto: UIImage?
    @State private var rightPhoto: UIImage?
    @State private var showingCamera = false
    @State private var activeSlot: AvatarSlot?
    @State private var showInfo = false
    @State private var errorMessage: String?

    enum AvatarSlot: String, CaseIterable {
        case front = "Front"
        case slightLeft = "Slight Left"
        case slightRight = "Slight Right"
    }

    private var allPhotosCapured: Bool {
        frontPhoto != nil && leftPhoto != nil && rightPhoto != nil
    }

    var body: some View {
        VStack(spacing: 24) {
            // Progress
            ProgressIndicator(step: 1, totalSteps: 3)

            Text("Build Your Avatar")
                .font(.title)
                .fontWeight(.bold)

            HStack {
                Text("Take 3 quick photos so we can show outfits on you — not a generic model.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            // Photo slots
            HStack(spacing: 16) {
                ForEach(AvatarSlot.allCases, id: \.rawValue) { slot in
                    AvatarPhotoSlot(
                        label: slot.rawValue,
                        image: imageForSlot(slot),
                        onTap: {
                            activeSlot = slot
                            showingCamera = true
                        }
                    )
                }
            }
            .padding(.horizontal)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Spacer()

            Button(action: saveAndContinue) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(allPhotosCapured ? Color.accentColor : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!allPhotosCapured)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(image: bindingForActiveSlot())
        }
        .alert("Why do we need this?", isPresented: $showInfo) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text("These photos are used only for try-on renders so you can see how outfits look on you. They are stored locally on your device and iCloud only. They are never shared or used for training.")
        }
    }

    private func imageForSlot(_ slot: AvatarSlot) -> UIImage? {
        switch slot {
        case .front: return frontPhoto
        case .slightLeft: return leftPhoto
        case .slightRight: return rightPhoto
        }
    }

    private func bindingForActiveSlot() -> Binding<UIImage?> {
        switch activeSlot {
        case .front: return $frontPhoto
        case .slightLeft: return $leftPhoto
        case .slightRight: return $rightPhoto
        case .none: return $frontPhoto
        }
    }

    private func saveAndContinue() {
        guard let front = frontPhoto, let left = leftPhoto, let right = rightPhoto else { return }

        let photos = [("front.jpg", front), ("left.jpg", left), ("right.jpg", right)]
        var fileNames: [String] = []

        for (name, image) in photos {
            do {
                _ = try ImageService.shared.saveAvatarPhoto(image, fileName: name)
                fileNames.append(name)
            } catch {
                errorMessage = "Failed to save photo: \(error.localizedDescription)"
                return
            }
        }

        let profile = UserProfile()
        profile.avatarPhotoFileNames = fileNames
        modelContext.insert(profile)
        try? modelContext.save()

        onContinue()
    }
}

struct AvatarPhotoSlot: View {
    let label: String
    let image: UIImage?
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: onTap) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .aspectRatio(0.65, contentMode: .fit)

                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.quaternary)
                            Image(systemName: "camera.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct ClosetImportScreen: View {
    let onContinue: () -> Void
    @State private var showBatchImport = false
    @State private var showSingleImport = false
    @State private var showOnlineSearch = false

    var body: some View {
        VStack(spacing: 24) {
            ProgressIndicator(step: 2, totalSteps: 3)

            Text("Import Your Closet")
                .font(.title)
                .fontWeight(.bold)

            Text("Choose how you'd like to add your clothes")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 16) {
                ImportOptionCard(
                    icon: "camera.viewfinder",
                    title: "Batch Photo",
                    description: "Photograph a pile of clothes, we'll separate them",
                    action: { showBatchImport = true }
                )

                ImportOptionCard(
                    icon: "camera",
                    title: "Single Item",
                    description: "Add one piece at a time",
                    action: { showSingleImport = true }
                )

                ImportOptionCard(
                    icon: "magnifyingglass",
                    title: "Search Online",
                    description: "Find an item by brand/name and import the product image",
                    action: { showOnlineSearch = true }
                )
            }
            .padding(.horizontal)

            Spacer()

            Button(action: onContinue) {
                Text("I'll do this later")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showBatchImport) {
            AddItemBatchView()
        }
        .sheet(isPresented: $showSingleImport) {
            AddItemSingleView()
        }
        .sheet(isPresented: $showOnlineSearch) {
            OnlineSearchView()
        }
    }
}

struct ImportOptionCard: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.accent)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct StyleBaselineScreen: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @State private var dressesFor = "mix"
    @State private var excludedColors: Set<String> = []
    @State private var styleDescription = "classic"
    @State private var decisionTime = "under_1_min"
    @State private var morningPref = "check_manually"

    let colorOptions = ["Black", "White", "Navy", "Gray", "Brown", "Beige",
                        "Red", "Pink", "Orange", "Yellow", "Green", "Blue", "Purple"]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                ProgressIndicator(step: 3, totalSteps: 3)

                Text("Style Baseline")
                    .font(.title)
                    .fontWeight(.bold)

                // Q1
                QuestionSection(title: "What do you mainly dress for?") {
                    ChipSelector(
                        options: ["Work", "Casual", "Going out", "Mix of everything"],
                        values: ["work", "casual", "going_out", "mix"],
                        selected: $dressesFor
                    )
                }

                // Q2
                QuestionSection(title: "Any colors you never wear?") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                        ForEach(colorOptions, id: \.self) { color in
                            ColorChip(
                                colorName: color,
                                isSelected: excludedColors.contains(color),
                                onTap: {
                                    if excludedColors.contains(color) {
                                        excludedColors.remove(color)
                                    } else {
                                        excludedColors.insert(color)
                                    }
                                }
                            )
                        }
                    }
                }

                // Q3
                QuestionSection(title: "How would you describe your style?") {
                    ChipSelector(
                        options: ["Minimal", "Classic", "Streetwear", "Feminine", "Eclectic", "Still figuring it out"],
                        values: ["minimal", "classic", "streetwear", "feminine", "eclectic", "figuring_out"],
                        selected: $styleDescription
                    )
                }

                // Q4
                QuestionSection(title: "How much time on outfit decisions?") {
                    ChipSelector(
                        options: ["Under 1 min", "A few minutes", "I like exploring"],
                        values: ["under_1_min", "few_minutes", "like_exploring"],
                        selected: $decisionTime
                    )
                }

                // Q5
                QuestionSection(title: "Morning outfit suggestions?") {
                    ChipSelector(
                        options: ["Yes, notify me", "Yes, I'll check manually", "No thanks"],
                        values: ["notify", "check_manually", "no"],
                        selected: $morningPref
                    )
                }

                Button(action: finishOnboarding) {
                    Text("Finish")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .padding()
        }
    }

    private func finishOnboarding() {
        let descriptor = FetchDescriptor<UserProfile>()
        if let profile = try? modelContext.fetch(descriptor).first {
            let prefs = StylePreferences(
                dressesFor: dressesFor,
                excludedColors: Array(excludedColors),
                styleDescription: styleDescription,
                decisionTime: decisionTime,
                morningNotificationPref: morningPref
            )
            profile.stylePreferences = prefs
            profile.hasCompletedOnboarding = true
            profile.notificationsEnabled = morningPref == "notify"
            try? modelContext.save()
        }

        appState.hasCompletedOnboarding = true
    }
}

// MARK: - Reusable Components

struct ProgressIndicator: View {
    let step: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? Color.accentColor : Color(.systemGray4))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 8)

        Text("Step \(step) of \(totalSteps)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

struct QuestionSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
        }
    }
}

struct ChipSelector: View {
    let options: [String]
    let values: [String]
    @Binding var selected: String

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(zip(options, values)), id: \.1) { option, value in
                Button {
                    selected = value
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text(option)
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selected == value ? Color.accentColor : Color(.systemGray5))
                        .foregroundStyle(selected == value ? .white : .primary)
                        .clipShape(Capsule())
                }
            }
        }
    }
}

struct ColorChip: View {
    let colorName: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            onTap()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            Text(colorName)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(isSelected ? Color.red.opacity(0.2) : Color(.systemGray5))
                .foregroundStyle(isSelected ? .red : .primary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? Color.red : Color.clear, lineWidth: 1)
                )
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
