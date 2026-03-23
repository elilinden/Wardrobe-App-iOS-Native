import SwiftUI
import SwiftData

enum ClosetSegment: String, CaseIterable {
    case myCloset = "My Closet"
    case wishlist = "Wishlist"
}

enum ClosetViewMode: String, CaseIterable {
    case grid, list, colorWall

    var icon: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        case .colorWall: return "paintpalette"
        }
    }

    var label: String {
        switch self {
        case .grid: return "Grid"
        case .list: return "List"
        case .colorWall: return "Color Wall"
        }
    }
}

struct ClosetView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \WardrobeItem.dateAdded, order: .reverse) private var allItems: [WardrobeItem]

    @State private var segment: ClosetSegment = .myCloset
    @State private var viewMode: ClosetViewMode = .grid
    @State private var searchText = ""
    @State private var showFilters = false
    @State private var showAddItem = false
    @State private var showSettings = false
    @State private var selectedItem: WardrobeItem?

    // Filters
    @State private var filterCategories: Set<Category> = []
    @State private var filterColors: Set<String> = []
    @State private var filterSeasons: Set<Season> = []
    @State private var filterFormalities: Set<Formality> = []
    @State private var filterConditions: Set<ItemCondition> = []

    private var hasActiveFilters: Bool {
        !filterCategories.isEmpty || !filterColors.isEmpty ||
        !filterSeasons.isEmpty || !filterFormalities.isEmpty ||
        !filterConditions.isEmpty
    }

    private var currentItems: [WardrobeItem] {
        allItems.filter { segment == .myCloset ? !$0.isWishlist : $0.isWishlist }
    }

    private var filteredItems: [WardrobeItem] {
        currentItems.filter { item in
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                let match = (item.name?.lowercased().contains(q) ?? false) ||
                    (item.brand?.lowercased().contains(q) ?? false) ||
                    item.primaryColor.lowercased().contains(q) ||
                    item.categoryRaw.contains(q) ||
                    item.subcategory.lowercased().contains(q)
                if !match { return false }
            }
            if !filterCategories.isEmpty && !filterCategories.contains(item.category) { return false }
            if !filterColors.isEmpty && !filterColors.contains(item.primaryColor.lowercased()) { return false }
            if !filterSeasons.isEmpty && item.seasons.allSatisfy({ !filterSeasons.contains($0) }) { return false }
            if !filterFormalities.isEmpty && !filterFormalities.contains(item.formality) { return false }
            if !filterConditions.isEmpty && !filterConditions.contains(item.condition) { return false }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground()

                VStack(spacing: 0) {
                    // Segment
                    Picker("", selection: $segment) {
                        ForEach(ClosetSegment.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, DS.spacingLG)
                    .padding(.vertical, DS.spacingSM)

                    // Nudge banner
                    if appState.showClosetNudgeBanner && segment == .myCloset {
                        nudgeBanner
                    }

                    // Content
                    if filteredItems.isEmpty {
                        EmptyStateView(
                            icon: segment == .myCloset ? "tshirt" : "heart",
                            title: segment == .myCloset ? "Your wardrobe starts here." : "Your wishlist is empty.",
                            subtitle: segment == .myCloset
                                ? "Add your first item to get started."
                                : "Share items from Safari or other apps.",
                            actionTitle: segment == .myCloset ? "Add Item" : nil,
                            action: segment == .myCloset ? { showAddItem = true } : nil
                        )
                    } else {
                        switch viewMode {
                        case .grid: gridView
                        case .list: listView
                        case .colorWall: colorWallView
                        }
                    }
                }
            }
            .navigationTitle("Closet")
            .searchable(text: $searchText, prompt: "Search by color, category, brand...")
            .toolbar { toolbarContent }
            .sheet(isPresented: $showFilters) {
                FilterSheetView(
                    selectedCategories: $filterCategories,
                    selectedColors: $filterColors,
                    selectedSeasons: $filterSeasons,
                    selectedFormalities: $filterFormalities,
                    selectedConditions: $filterConditions
                )
            }
            .sheet(isPresented: $showAddItem) { AddItemMenuView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(item: $selectedItem) { item in ItemDetailView(item: item) }
            .onAppear {
                appState.closetItemCount = allItems.filter { !$0.isWishlist }.count
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                ForEach(ClosetViewMode.allCases, id: \.self) { mode in
                    Button {
                        viewMode = mode
                        Haptic.selection()
                    } label: {
                        Label(mode.label, systemImage: mode.icon)
                    }
                }
            } label: {
                Image(systemName: viewMode.icon)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: DS.spacingMD) {
                Button { showFilters = true } label: {
                    Image(systemName: hasActiveFilters
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                }

                Button { showAddItem = true } label: {
                    Image(systemName: "plus.circle.fill")
                }

                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
    }

    // MARK: - Nudge Banner

    private var nudgeBanner: some View {
        HStack(spacing: DS.spacingMD) {
            Image(systemName: "sparkles")
                .foregroundStyle(.accent)
            Text("Add at least 5 items to unlock outfit suggestions")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(DS.spacingMD)
        .glassBackground(cornerRadius: DS.radiusMD)
        .padding(.horizontal, DS.spacingLG)
        .padding(.bottom, DS.spacingSM)
    }

    // MARK: - Grid

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: DS.gridColumns3, spacing: DS.spacingMD) {
                ForEach(filteredItems, id: \.id) { item in
                    ItemCardView(item: item)
                        .onTapGesture {
                            selectedItem = item
                            Haptic.selection()
                        }
                        .contextMenu { itemContextMenu(item) }
                }
            }
            .padding(DS.spacingLG)
        }
    }

    // MARK: - List

    private var listView: some View {
        List(filteredItems, id: \.id) { item in
            HStack(spacing: DS.spacingMD) {
                ItemThumbnail(item: item, size: 56)
                VStack(alignment: .leading, spacing: DS.spacingXS) {
                    Text(item.displayName)
                        .font(.subheadline.weight(.medium))
                    HStack(spacing: DS.spacingXS) {
                        Text(item.category.displayName)
                        if let brand = item.brand { Text("· \(brand)") }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if item.condition != .clean {
                    Image(systemName: item.condition.icon)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { selectedItem = item }
            .listRowBackground(Color.clear)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    item.cleanupPhoto()
                    modelContext.delete(item)
                } label: { Label("Delete", systemImage: "trash") }

                Button {
                    item.moveToStorage()
                } label: { Label("Storage", systemImage: "archivebox") }
                    .tint(.blue)
            }
            .swipeActions(edge: .leading) {
                Button {
                    item.markWornToday()
                } label: { Label("Worn", systemImage: "checkmark.circle") }
                    .tint(.green)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Color Wall

    private var colorWallView: some View {
        let grouped = Dictionary(grouping: filteredItems) { $0.primaryColor.lowercased() }
        let sortedColors = grouped.keys.sorted()

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: DS.spacingLG) {
                ForEach(sortedColors, id: \.self) { color in
                    VStack(alignment: .leading, spacing: DS.spacingSM) {
                        Text(color.capitalized)
                            .font(.headline)
                            .padding(.horizontal, DS.spacingLG)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DS.spacingSM) {
                                ForEach(grouped[color] ?? [], id: \.id) { item in
                                    ItemThumbnail(item: item, size: 72)
                                        .onTapGesture { selectedItem = item }
                                }
                            }
                            .padding(.horizontal, DS.spacingLG)
                        }
                    }
                }
            }
            .padding(.vertical, DS.spacingLG)
        }
    }

    @ViewBuilder
    private func itemContextMenu(_ item: WardrobeItem) -> some View {
        Button { item.markWornToday() } label: {
            Label("Mark Worn Today", systemImage: "checkmark.circle")
        }
        Button { item.moveToStorage() } label: {
            Label("Move to Storage", systemImage: "archivebox")
        }
        Divider()
        Button(role: .destructive) {
            item.cleanupPhoto()
            modelContext.delete(item)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}
