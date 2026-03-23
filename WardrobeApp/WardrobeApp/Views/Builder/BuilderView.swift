import SwiftUI
import SwiftData

struct BuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<WardrobeItem> { !$0.isWishlist })
    private var allItems: [WardrobeItem]

    @State private var selectedTop: WardrobeItem?
    @State private var selectedBottom: WardrobeItem?
    @State private var selectedDress: WardrobeItem?
    @State private var selectedOuterwear: WardrobeItem?
    @State private var selectedShoes: WardrobeItem?
    @State private var selectedAccessories: [WardrobeItem] = []
    @State private var activeCategory: Category = .top
    @State private var showTryOn = false
    @State private var showSaveSheet = false
    @State private var showSettings = false
    @State private var outfitName = ""

    private var selectedItems: [WardrobeItem] {
        var items: [WardrobeItem] = []
        if let top = selectedTop { items.append(top) }
        if let bottom = selectedBottom { items.append(bottom) }
        if let dress = selectedDress { items.append(dress) }
        if let outerwear = selectedOuterwear { items.append(outerwear) }
        if let shoes = selectedShoes { items.append(shoes) }
        items.append(contentsOf: selectedAccessories)
        return items
    }

    private var categoryItems: [WardrobeItem] {
        allItems.filter { item in
            item.category == activeCategory &&
            item.condition != .inStorage
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top half: collage preview
                ZStack {
                    Color(.systemGray6)

                    if selectedItems.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "square.stack.3d.up")
                                .font(.system(size: 50))
                                .foregroundStyle(.quaternary)
                            Text("Select items below to build an outfit")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack(spacing: 8) {
                            ForEach(selectedItems, id: \.id) { item in
                                ItemThumbnail(item: item, size: nil)
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(0.7, contentMode: .fit)
                                    .onTapGesture { removeItem(item) }
                            }
                        }
                        .padding()
                    }
                }
                .frame(maxHeight: .infinity)
                .overlay(alignment: .topTrailing) {
                    if !selectedItems.isEmpty {
                        Button {
                            showTryOn = true
                        } label: {
                            Label("Try On", systemImage: "person.fill")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                        .padding()
                    }
                }

                Divider()

                // Bottom half: item selector
                VStack(spacing: 0) {
                    // Category tabs
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Category.allCases) { category in
                                Button {
                                    activeCategory = category
                                } label: {
                                    Text(category.displayName)
                                        .font(.subheadline)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(activeCategory == category ? Color.accentColor : Color(.systemGray5))
                                        .foregroundStyle(activeCategory == category ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }

                    // Items grid
                    if categoryItems.isEmpty {
                        VStack(spacing: 8) {
                            Text("No \(activeCategory.displayName.lowercased()) in your closet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(categoryItems, id: \.id) { item in
                                    ItemThumbnail(item: item, size: nil)
                                        .aspectRatio(0.8, contentMode: .fit)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(
                                                    isSelected(item) ? Color.accentColor : Color.clear,
                                                    lineWidth: 3
                                                )
                                        )
                                        .onTapGesture { selectItem(item) }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                // Actions bar
                if !selectedItems.isEmpty {
                    HStack(spacing: 12) {
                        Button { showSaveSheet = true } label: {
                            Label("Save", systemImage: "bookmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Menu {
                            Button {
                                pinToCalendar()
                            } label: {
                                Label("Pin to Calendar", systemImage: "calendar.badge.plus")
                            }
                            Button {
                                addToToday()
                            } label: {
                                Label("Add to Today", systemImage: "sun.max")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("Builder")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showTryOn) {
                TryOnView(items: selectedItems)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .alert("Save Outfit", isPresented: $showSaveSheet) {
                TextField("Outfit name (optional)", text: $outfitName)
                Button("Save") { saveOutfit() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func isSelected(_ item: WardrobeItem) -> Bool {
        selectedItems.contains(where: { $0.id == item.id })
    }

    private func selectItem(_ item: WardrobeItem) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch item.category {
        case .top:
            selectedTop = selectedTop?.id == item.id ? nil : item
        case .bottom:
            selectedBottom = selectedBottom?.id == item.id ? nil : item
        case .dress:
            selectedDress = selectedDress?.id == item.id ? nil : item
        case .outerwear:
            selectedOuterwear = selectedOuterwear?.id == item.id ? nil : item
        case .shoes:
            selectedShoes = selectedShoes?.id == item.id ? nil : item
        case .accessory:
            if let index = selectedAccessories.firstIndex(where: { $0.id == item.id }) {
                selectedAccessories.remove(at: index)
            } else if selectedAccessories.count < 3 {
                selectedAccessories.append(item)
            }
        }
    }

    private func removeItem(_ item: WardrobeItem) {
        switch item.category {
        case .top: selectedTop = nil
        case .bottom: selectedBottom = nil
        case .dress: selectedDress = nil
        case .outerwear: selectedOuterwear = nil
        case .shoes: selectedShoes = nil
        case .accessory: selectedAccessories.removeAll { $0.id == item.id }
        }
    }

    private func saveOutfit() {
        let outfit = Outfit(
            name: outfitName.isEmpty ? nil : outfitName,
            itemIDs: selectedItems.map(\.id)
        )
        modelContext.insert(outfit)
        try? modelContext.save()
        outfitName = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func pinToCalendar() {
        // In a full implementation, this would open a date picker
        saveOutfit()
    }

    private func addToToday() {
        let outfit = Outfit(
            itemIDs: selectedItems.map(\.id),
            plannedDate: Date()
        )
        modelContext.insert(outfit)
        try? modelContext.save()
    }
}
