import SwiftUI
import SwiftData

struct TryOnView: View {
    let items: [WardrobeItem]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var isRendering = false
    @State private var renderedImage: UIImage?
    @State private var errorMessage: String?
    @State private var showUpgradeSheet = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            VStack {
                if isRendering {
                    VStack(spacing: 20) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(2)
                        Text("Rendering your outfit...")
                            .font(.headline)
                        Text("This may take 10-20 seconds")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                } else if let rendered = renderedImage {
                    renderedResult(rendered)
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                        Button("Try Again") { startRender() }
                            .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                    .padding()
                } else {
                    // Preview before rendering
                    VStack(spacing: 16) {
                        Text("Preview")
                            .font(.headline)

                        HStack(spacing: 8) {
                            ForEach(items, id: \.id) { item in
                                ItemThumbnail(item: item, size: nil)
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(0.75, contentMode: .fit)
                            }
                        }
                        .padding(.horizontal)

                        if let profile = profile {
                            if profile.canRender {
                                Text("\(profile.rendersRemaining) renders remaining this month")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Button(action: startRender) {
                                    Label("Render Try-On", systemImage: "wand.and.stars")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.accentColor)
                                        .foregroundStyle(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .padding(.horizontal)
                            } else {
                                Text("You've used all 30 renders this month")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Button {
                                    showUpgradeSheet = true
                                } label: {
                                    Text("Unlock Unlimited Renders — $2.99")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.accentColor)
                                        .foregroundStyle(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .padding(.horizontal)
                            }
                        }

                        Spacer()
                    }
                }
            }
            .navigationTitle("Try On")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showUpgradeSheet) {
                UnlimitedRendersUpgradeView()
            }
        }
    }

    private func renderedResult(_ image: UIImage) -> some View {
        VStack(spacing: 16) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding()

            HStack(spacing: 12) {
                Button {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                ShareLink(item: Image(uiImage: image), preview: SharePreview("Outfit", image: Image(uiImage: image))) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)

            Button {
                saveToLookbook(image)
            } label: {
                Label("Add to Lookbook", systemImage: "bookmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
        }
    }

    private func startRender() {
        guard let profile = profile else { return }

        if !profile.canRender {
            showUpgradeSheet = true
            return
        }

        isRendering = true
        errorMessage = nil

        Task {
            guard let avatarURL = profile.avatarPhotoURLs.first,
                  let avatarImage = ImageService.shared.loadImage(from: avatarURL) else {
                await MainActor.run {
                    errorMessage = "Avatar photos not found. Please retake them in Settings."
                    isRendering = false
                }
                return
            }

            let garmentImages = items.compactMap { ImageService.shared.loadImage(from: $0.photoURL) }
            guard !garmentImages.isEmpty else {
                await MainActor.run {
                    errorMessage = "Could not load garment images."
                    isRendering = false
                }
                return
            }

            do {
                let result = try await TryOnService().renderOutfit(
                    personImage: avatarImage,
                    garmentImages: garmentImages
                )

                profile.incrementRenderCount()
                try? modelContext.save()

                await MainActor.run {
                    renderedImage = result
                    isRendering = false
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isRendering = false
                }
            }
        }
    }

    private func saveToLookbook(_ image: UIImage) {
        let fileName = "\(UUID().uuidString).jpg"
        try? ImageService.shared.saveTryOnRender(image, fileName: fileName)

        let outfit = Outfit(itemIDs: items.map(\.id))
        outfit.tryOnRenderFileName = fileName
        modelContext.insert(outfit)
        try? modelContext.save()

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

struct UnlimitedRendersUpgradeView: View {
    @StateObject private var storeService = StoreKitService()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "wand.and.stars")
                .font(.system(size: 60))
                .foregroundStyle(.accent)

            Text("Unlimited Try-On Renders")
                .font(.title2)
                .fontWeight(.bold)

            Text("See how any outfit looks on you — unlimited times, forever.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("$2.99")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("One-time purchase. No subscription.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if storeService.isLoading {
                ProgressView()
            } else {
                Button {
                    Task {
                        try? await storeService.purchaseUnlimitedRenders()
                        if storeService.hasUnlimitedRenders {
                            dismiss()
                        }
                    }
                } label: {
                    Text("Unlock Unlimited Renders")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
            }

            Button("Not now") { dismiss() }
                .foregroundStyle(.secondary)
                .padding(.bottom, 40)
        }
        .padding()
    }
}
