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
    @State private var showUpgrade = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            VStack {
                if isRendering {
                    GlassProgressView(
                        title: "Rendering your outfit...",
                        subtitle: "This may take 10-20 seconds"
                    )
                } else if let rendered = renderedImage {
                    renderedView(rendered)
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    preRenderView
                }
            }
            .background { MeshGradientBackground() }
            .navigationTitle("Try On")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showUpgrade) {
                UnlimitedRendersUpgradeView()
            }
        }
    }

    // MARK: - Pre-render

    private var preRenderView: some View {
        VStack(spacing: DS.spacingXL) {
            Spacer()

            Text("Preview")
                .font(.headline)

            HStack(spacing: DS.spacingSM) {
                ForEach(items, id: \.id) { item in
                    ItemThumbnail(item: item, showConditionBadge: false)
                        .aspectRatio(0.7, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, DS.spacingXL)

            if let profile {
                if profile.canRender {
                    Text("\(profile.rendersRemaining) renders remaining this month")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button(action: startRender) {
                        Label("Render Try-On", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(GlassButtonStyle())
                    .padding(.horizontal, DS.spacingXL)
                } else {
                    Text("You've used all \(DS.monthlyRenderLimit) renders this month")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button { showUpgrade = true } label: {
                        Text("Unlock Unlimited — $2.99")
                    }
                    .buttonStyle(GlassButtonStyle())
                    .padding(.horizontal, DS.spacingXL)
                }
            }

            Spacer()
        }
    }

    // MARK: - Rendered

    private func renderedView(_ image: UIImage) -> some View {
        ScrollView {
            VStack(spacing: DS.spacingLG) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: DS.radiusXL))
                    .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
                    .padding(.horizontal, DS.spacingLG)

                HStack(spacing: DS.spacingMD) {
                    Button {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        Haptic.success()
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    ShareLink(
                        item: Image(uiImage: image),
                        preview: SharePreview("Outfit", image: Image(uiImage: image))
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .font(.subheadline.weight(.medium))
                            .padding(.vertical, 12)
                            .background {
                                RoundedRectangle(cornerRadius: DS.radiusMD)
                                    .fill(.ultraThinMaterial)
                            }
                    }
                }
                .padding(.horizontal, DS.spacingLG)

                Button { saveToLookbook(image) } label: {
                    Label("Add to Lookbook", systemImage: "bookmark")
                }
                .buttonStyle(GlassButtonStyle())
                .padding(.horizontal, DS.spacingLG)
            }
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: DS.spacingLG) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Try Again") { startRender() }
                .buttonStyle(GlassButtonStyle())
                .padding(.horizontal, DS.spacingXL)
            Spacer()
        }
    }

    // MARK: - Actions

    private func startRender() {
        guard let profile else { return }
        guard profile.canRender else {
            showUpgrade = true
            return
        }

        isRendering = true
        errorMessage = nil

        Task {
            guard let avatarURL = profile.avatarPhotoURLs.first,
                  let avatar = ImageCache.shared.load(from: avatarURL) else {
                await MainActor.run {
                    errorMessage = "Avatar photos not found. Please retake in Settings."
                    isRendering = false
                }
                return
            }

            let garments = items.compactMap { ImageCache.shared.load(from: $0.photoURL) }
            guard !garments.isEmpty else {
                await MainActor.run {
                    errorMessage = "Could not load garment images."
                    isRendering = false
                }
                return
            }

            do {
                let result = try await TryOnService().renderOutfit(
                    personImage: avatar, garmentImages: garments
                )
                profile.incrementRenderCount()
                try? modelContext.save()

                await MainActor.run {
                    renderedImage = result
                    isRendering = false
                    Haptic.medium()
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
        let fileName = try? ImageService.shared.saveTryOnRender(image)
        let outfit = Outfit(itemIDs: items.map(\.id))
        outfit.tryOnRenderFileName = fileName
        modelContext.insert(outfit)
        try? modelContext.save()
        Haptic.success()
    }
}

// MARK: - Upgrade Sheet

struct UnlimitedRendersUpgradeView: View {
    @StateObject private var store = StoreKitService()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: DS.spacingXL) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 120, height: 120)
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 44))
                    .foregroundStyle(.accent)
                    .symbolEffect(.pulse)
            }

            VStack(spacing: DS.spacingMD) {
                Text("Unlimited Try-On Renders")
                    .font(.title2.weight(.bold))

                Text("See how any outfit looks on you.\nUnlimited times, forever.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text("$2.99")
                .font(.system(size: 44, weight: .bold, design: .rounded))

            Text("One-time purchase. No subscription.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if store.isLoading {
                ProgressView()
            } else {
                Button {
                    Task {
                        try? await store.purchaseUnlimitedRenders()
                        if store.hasUnlimitedRenders { dismiss() }
                    }
                } label: {
                    Text("Unlock Unlimited Renders")
                }
                .buttonStyle(GlassButtonStyle())
                .padding(.horizontal, DS.spacingXL)
            }

            Button("Not now") { dismiss() }
                .foregroundStyle(.secondary)
                .padding(.bottom, 40)
        }
        .padding(DS.spacingLG)
        .background { MeshGradientBackground() }
    }
}
