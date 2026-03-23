import SwiftUI
import SwiftData

enum ClosetSegment: String, CaseIterable {
    case myCloset = "My Closet"
    case wishlist = "Wishlist"
}

enum ClosetViewMode: String, CaseIterable {
    case grid = "Grid"
    case list = "List"
    case colorWall = "Color Wall"

    var icon: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        case .colorWall: return "paintpalette"
        }
    }
}

struct ClosetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<WardrobeItem> { !$0.isWishlist },
           sort: \WardrobeItem.dateAdded, order: .reverse)
    private var closetItems: [WardrobeItem]

    @Query(filter: #Predicate<WardrobeItem> { $0.isWishlist },
           sort: \WardrobeItem.dateAdded, order: .reverse)
    private var wishlistItems: [WardrobeItem]

    @State private var segment: ClosetSegment = .myCloset
    @State private var viewMode: ClosetViewMode = .grid
    @State private var searchText = ""
    @State private var showFilterSheet = false
    @State private var showAddItem = false
    @State private var showSettings = false
    @State private var selectedItem: WardrobeItem?

    // Filters
    @State private var filterCategories: Set<Category> = []
    @State private var filterColors: Set<String> = []
    @State private var filterSeasons: Set<Season> = []
    @State private var filterFormalities: Set<Formality> = []
    @State private var filterConditions: Set<ItemCondition> = []

    private var currentItems: [WardrobeItem] {
        segment == .myCloset ? closetItems : wishlistItems
    }

    private var filteredItems: [WardrobeItem] {
        currentItems.filter { item in
            // Search
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                let matches = (item.name?.lowercased().contains(query) ?? false) ||
                    (item.brand?.lowercased().contains(query) ?? false) ||
                    item.primaryColor.lowercased().contains(query) ||
                    item.categoryRaw.lowercased().contains(query) ||
                    item.subcategory.lowercased().contains(query)
                if !matches { return false }
            }

            // Category filter
            if !filterCategories.isEmpty && !filterCategories.contains(item.category) {
                return false
            }

            // Color filter
            if !filterColors.isEmpty && !filterColors.contains(item.primaryColor.lowercased()) {
                return false
            }

            // Season filter
            if !filterSeasons.isEmpty && item.seasons.allSatisfy({ !filterSeasons.contains($0) }) {
                return false
            }

            // Formality filter
            if !filterFormalities.isEmpty && !filterFormalities.contains(item.formality) {
                return false
            }

            // Condition filter
            if !filterConditions.isEmpty && !filterConditions.contains(item.condition) {
                return false
            }

            return true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segment control
                Picker("", selection: $segment) {
                    ForEach(ClosetSegment.allCases, id: \.self) { seg in
                        Text(seg.rawValue).tag(seg)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                if filteredItems.isEmpty {
                    emptyState
                } else {
                    switch viewMode {
                    case .grid:
                        gridView
                    case .list:
                        listView
                    case .colorWall:
                        colorWallView
                    }
                }
            }
            .navigationTitle("Closet")
            .searchable(text: $searchText, prompt: "Search by color, category, brand...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(ClosetViewMode.allCases, id: \.self) { mode in
                            Button {
                                viewMode = mode
                            } label: {
                                Label(mode.rawValue, systemImage: mode.icon)
                            }
                        }
                    } label: {
                        Image(systemName: viewMode.icon)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button { showFilterSheet = true } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }

                        Button { showAddItem = true } label: {
                            Image(systemName: "plus")
                        }

                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheetView(
                    selectedCategories: $filterCategories,
                    selectedColors: $filterColors,
                    selectedSeasons: $filterSeasons,
                    selectedFormalities: $filterFormalities,
                    selectedConditions: $filterConditions
                )
            }
            .sheet(isPresented: $showAddItem) {
                AddItemMenuView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(item: $selectedItem) { item in
                ItemDetailView(item: item)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: segment == .myCloset ? "tshirt" : "heart")
                .font(.system(size: 60))
                .foregroundStyle(.quaternary)

            if segment == .myCloset {
                Text("Your wardrobe starts here.")
                    .font(.title3)
                    .fontWeight(.medium)
                Text("Add your first item.")
                    .foregroundStyle(.secondary)
                Button("Add Item") { showAddItem = true }
                    .buttonStyle(.borderedProminent)
            } else {
                Text("Your wishlist is empty.")
                    .font(.title3)
                    .fontWeight(.medium)
                Text("Share items from Safari or other apps to add them here.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Spacer()
        }
    }

    // MARK: - Grid View

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(filteredItems, id: \.id) { item in
                    ItemCardView(item: item)
                        .onTapGesture { selectedItem = item }
                        .contextMenu {
                            itemContextMenu(item: item)
                        }
                }
            }
            .padding()
        }
    }

    // MARK: - List View

    private var listView: some View {
        List(filteredItems, id: \.id) { item in
            HStack(spacing: 12) {
                ItemThumbnail(item: item, size: 60)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name ?? item.subcategory.capitalized)
                        .font(.headline)
                    Text(item.category.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let brand = item.brand {
                        Text(brand)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if item.condition != .clean {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { selectedItem = item }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    modelContext.delete(item)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                Button {
                    item.condition = .inStorage
                } label: {
                    Label("Storage", systemImage: "archivebox")
                }
                .tint(.blue)
            }
            .swipeActions(edge: .leading) {
                Button {
                    item.timesWorn += 1
                    item.lastWorn = Date()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Label("Worn Today", systemImage: "checkmark.circle")
                }
                .tint(.green)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Color Wall View

    private var colorWallView: some View {
        let grouped = Dictionary(grouping: filteredItems) { $0.primaryColor.lowercased() }
        let sortedColors = grouped.keys.sorted()

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(sortedColors, id: \.self) { color in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(color.capitalized)
                            .font(.headline)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(grouped[color] ?? [], id: \.id) { item in
                                    ItemThumbnail(item: item, size: 80)
                                        .onTapGesture { selectedItem = item }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }

    @ViewBuilder
    private func itemContextMenu(item: WardrobeItem) -> some View {
        Button {
            item.timesWorn += 1
            item.lastWorn = Date()
        } label: {
            Label("Mark Worn Today", systemImage: "checkmark.circle")
        }

        Button {
            item.condition = .inStorage
        } label: {
            Label("Move to Storage", systemImage: "archivebox")
        }

        Button(role: .destructive) {
            modelContext.delete(item)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

struct ItemCardView: View {
    let item: WardrobeItem

    var body: some View {
        VStack(spacing: 4) {
            ItemThumbnail(item: item, size: nil)
                .aspectRatio(0.8, contentMode: .fit)

            Text(item.name ?? item.subcategory.capitalized)
                .font(.caption)
                .lineLimit(1)

            Text(item.category.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct ItemThumbnail: View {
    let item: WardrobeItem
    let size: CGFloat?

    var body: some View {
        Group {
            if let image = ImageService.shared.loadImage(from: item.photoURL) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(.systemGray5)
                    Image(systemName: "tshirt")
                        .foregroundStyle(.quaternary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .topTrailing) {
            if item.condition != .clean {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(4)
            }
        }
    }
}
