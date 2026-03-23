import SwiftUI
import SwiftData

struct OutfitDetailView: View {
    @Bindable var outfit: Outfit
    let allItems: [WardrobeItem]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showTryOn = false
    @State private var showDelete = false

    private var outfitItems: [WardrobeItem] {
        outfit.resolveItems(from: allItems)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.spacingXL) {
                    // Hero
                    heroSection

                    // Items
                    VStack(alignment: .leading, spacing: DS.spacingMD) {
                        Text("Items").font(.headline)
                        ForEach(outfitItems, id: \.id) { item in
                            HStack(spacing: DS.spacingMD) {
                                ItemThumbnail(item: item, size: 44, showConditionBadge: false)
                                Text(item.displayName)
                                    .font(.subheadline)
                                Spacer()
                                Text(item.category.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .glassCard()
                    .padding(.horizontal, DS.spacingLG)

                    // Tags
                    if outfit.occasion != nil || outfit.season != nil {
                        HStack(spacing: DS.spacingSM) {
                            if let occ = outfit.occasion {
                                TagPill(text: occ.displayName, color: .blue)
                            }
                            if let s = outfit.season {
                                TagPill(text: s.displayName, color: .teal)
                            }
                        }
                        .padding(.horizontal, DS.spacingLG)
                    }

                    // Worn dates
                    if !outfit.wornDates.isEmpty {
                        VStack(alignment: .leading, spacing: DS.spacingSM) {
                            Text("Worn on").font(.caption).foregroundStyle(.secondary)
                            ForEach(outfit.wornDates, id: \.self) { date in
                                Text(date, format: .dateTime.month(.wide).day().year())
                                    .font(.caption)
                            }
                        }
                        .glassCard()
                        .padding(.horizontal, DS.spacingLG)
                    }

                    // Actions
                    VStack(spacing: DS.spacingMD) {
                        Button {
                            AppLog.outfit.info("Marking outfit worn: \(outfit.displayName)")
                            outfit.markWorn(items: outfitItems)
                            do {
                                try modelContext.save()
                                AppLog.outfit.info("Outfit wear logged successfully")
                            } catch {
                                AppLog.data.error("Failed to save wear log: \(error.localizedDescription)")
                            }
                        } label: {
                            Label("Wear Again", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(GlassButtonStyle())

                        Button { showTryOn = true } label: {
                            Label("Try On", systemImage: "person.fill")
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        Button {
                            outfit.isFavorite.toggle()
                            AppLog.outfit.info("Outfit \(outfit.displayName) favorite: \(outfit.isFavorite)")
                            Haptic.light()
                        } label: {
                            Label(
                                outfit.isFavorite ? "Unfavorite" : "Favorite",
                                systemImage: outfit.isFavorite ? "heart.fill" : "heart"
                            )
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        Button(role: .destructive) { showDelete = true } label: {
                            Label("Delete", systemImage: "trash")
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, DS.spacingLG)
                    .padding(.bottom, DS.spacingXXL)
                }
            }
            .background { MeshGradientBackground() }
            .navigationTitle(outfit.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showTryOn) { TryOnView(items: outfitItems) }
            .alert("Delete outfit?", isPresented: $showDelete) {
                Button("Delete", role: .destructive) {
                    outfit.cleanupRender()
                    modelContext.delete(outfit)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    @ViewBuilder
    private var heroSection: some View {
        if let url = outfit.tryOnRenderURL, let image = ImageCache.shared.load(from: url) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 380)
                .clipShape(RoundedRectangle(cornerRadius: DS.radiusXL))
                .shadow(color: .black.opacity(0.1), radius: 20, y: 8)
                .padding(.horizontal, DS.spacingLG)
        } else {
            HStack(spacing: DS.spacingSM) {
                ForEach(outfitItems, id: \.id) { item in
                    ItemThumbnail(item: item, showConditionBadge: false)
                        .aspectRatio(0.7, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                }
            }
            .glassCard()
            .padding(.horizontal, DS.spacingLG)
        }
    }
}
