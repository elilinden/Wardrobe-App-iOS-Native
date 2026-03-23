import SwiftUI
import SwiftData

enum LookbookFilter: String, CaseIterable {
    case all = "All"
    case favorites = "Favorites"
    case calendar = "Calendar"
}

struct LookbookView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \Outfit.createdDate, order: .reverse) private var outfits: [Outfit]
    @Query private var items: [WardrobeItem]

    @State private var filter: LookbookFilter = .all
    @State private var selectedOutfit: Outfit?
    @State private var showSettings = false

    private var filteredOutfits: [Outfit] {
        switch filter {
        case .all: return outfits
        case .favorites: return outfits.filter(\.isFavorite)
        case .calendar: return outfits
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $filter) {
                    ForEach(LookbookFilter.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, DS.spacingLG)
                .padding(.vertical, DS.spacingSM)

                if filter == .calendar {
                    CalendarLookbookView(outfits: outfits, allItems: items)
                } else if filteredOutfits.isEmpty {
                    EmptyStateView(
                        icon: "book.closed",
                        title: "Save outfits here",
                        subtitle: "Build and save outfits for inspiration later.",
                        illustration: .emptyLookbook,
                        actionTitle: "Create Outfit",
                        action: { appState.selectedTab = 2 }
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: DS.gridColumns2, spacing: DS.spacingMD) {
                            ForEach(filteredOutfits, id: \.id) { outfit in
                                OutfitCardView(outfit: outfit, allItems: items)
                                    .onTapGesture {
                                        selectedOutfit = outfit
                                        Haptic.selection()
                                    }
                                    .contextMenu {
                                        Button {
                                            outfit.isFavorite.toggle()
                                            Haptic.light()
                                        } label: {
                                            Label(
                                                outfit.isFavorite ? "Unfavorite" : "Favorite",
                                                systemImage: outfit.isFavorite ? "heart.slash" : "heart"
                                            )
                                        }
                                        Button(role: .destructive) {
                                            AppLog.outfit.info("Deleting outfit: \(outfit.displayName)")
                                            outfit.cleanupRender()
                                            modelContext.delete(outfit)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(DS.spacingLG)
                    }
                }
            }
            .background { MeshGradientBackground() }
            .navigationTitle("Lookbook")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(item: $selectedOutfit) { outfit in
                OutfitDetailView(outfit: outfit, allItems: items)
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }
}

struct OutfitCardView: View {
    let outfit: Outfit
    let allItems: [WardrobeItem]

    private var outfitItems: [WardrobeItem] {
        outfit.resolveItems(from: allItems)
    }

    var body: some View {
        VStack(spacing: DS.spacingXS) {
            ZStack {
                if let url = outfit.tryOnRenderURL,
                   let image = ImageCache.shared.load(from: url) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    HStack(spacing: 2) {
                        ForEach(outfitItems.prefix(3), id: \.id) { item in
                            ItemThumbnail(item: item, showConditionBadge: false)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(DS.spacingSM)
                    .background(.ultraThinMaterial)
                }
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: DS.radiusLG))
            .overlay(alignment: .topTrailing) {
                if outfit.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding(DS.spacingSM)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: DS.radiusLG)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            }

            Text(outfit.displayName)
                .font(.caption.weight(.medium))
                .lineLimit(1)

            if let occasion = outfit.occasion {
                Text(occasion.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
