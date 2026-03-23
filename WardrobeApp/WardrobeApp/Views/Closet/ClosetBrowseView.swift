import SwiftUI
import SwiftData

/// Browse closet items organized by Season > Category hierarchy.
/// e.g. "Fall" → "Pants", "Shirts", etc.
struct ClosetBrowseView: View {
    @Query(filter: #Predicate<WardrobeItem> { !$0.isWishlist },
           sort: \WardrobeItem.dateAdded, order: .reverse)
    private var items: [WardrobeItem]

    @State private var selectedSeason: Season?
    @State private var selectedCategory: Category?
    @State private var selectedItem: WardrobeItem?

    private var seasons: [Season] {
        var seen = Set<Season>()
        for item in items {
            for season in item.seasons {
                seen.insert(season)
            }
        }
        return Season.allCases.filter { seen.contains($0) }
    }

    private var categoriesForSeason: [Category] {
        guard let season = selectedSeason else { return [] }
        let filtered = items.filter { $0.seasons.contains(season) }
        let cats = Set(filtered.map(\.category))
        return Category.allCases.filter { cats.contains($0) }
    }

    private var itemsForSelection: [WardrobeItem] {
        items.filter { item in
            if let season = selectedSeason, !item.seasons.contains(season) { return false }
            if let cat = selectedCategory, item.category != cat { return false }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Season chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.spacingSM) {
                    GlassChip(title: "All Seasons", isSelected: selectedSeason == nil) {
                        selectedSeason = nil
                        selectedCategory = nil
                    }

                    ForEach(seasons, id: \.self) { season in
                        GlassChip(title: season.displayName, isSelected: selectedSeason == season) {
                            if selectedSeason == season {
                                selectedSeason = nil
                                selectedCategory = nil
                            } else {
                                selectedSeason = season
                                selectedCategory = nil
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.spacingLG)
                .padding(.vertical, DS.spacingSM)
            }

            // Category chips (when a season is selected)
            if selectedSeason != nil {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.spacingSM) {
                        GlassChip(title: "All", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }

                        ForEach(categoriesForSeason) { cat in
                            let count = items.filter { $0.seasons.contains(selectedSeason!) && $0.category == cat }.count
                            GlassChip(
                                title: "\(cat.displayName) (\(count))",
                                isSelected: selectedCategory == cat
                            ) {
                                selectedCategory = selectedCategory == cat ? nil : cat
                            }
                        }
                    }
                    .padding(.horizontal, DS.spacingLG)
                    .padding(.bottom, DS.spacingSM)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Breadcrumb
            if selectedSeason != nil || selectedCategory != nil {
                HStack(spacing: DS.spacingXS) {
                    if let season = selectedSeason {
                        Text(season.displayName)
                            .font(.caption.weight(.semibold))
                    }
                    if selectedCategory != nil {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if let cat = selectedCategory {
                        Text(cat.displayName)
                            .font(.caption.weight(.semibold))
                    }
                    Spacer()
                    Text("\(itemsForSelection.count) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DS.spacingLG)
                .padding(.bottom, DS.spacingSM)
            }

            // Items grid
            if itemsForSelection.isEmpty {
                VStack(spacing: DS.spacingMD) {
                    Spacer()
                    Image(systemName: "tshirt")
                        .font(.system(size: 36))
                        .foregroundStyle(.quaternary)
                    Text("No items in this category")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: DS.gridColumns3, spacing: DS.spacingMD) {
                        ForEach(itemsForSelection, id: \.id) { item in
                            ItemCardView(item: item)
                                .onTapGesture {
                                    selectedItem = item
                                    Haptic.selection()
                                }
                        }
                    }
                    .padding(DS.spacingLG)
                }
            }
        }
        .animation(.spring(response: 0.3), value: selectedSeason)
        .animation(.spring(response: 0.3), value: selectedCategory)
        .sheet(item: $selectedItem) { item in
            ItemDetailView(item: item)
        }
    }
}
