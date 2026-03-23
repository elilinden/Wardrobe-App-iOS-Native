import SwiftUI
import SwiftData

struct BuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(filter: #Predicate<WardrobeItem> { !$0.isWishlist }) private var allItems: [WardrobeItem]

    @State private var selectedTop: WardrobeItem?
    @State private var selectedBottom: WardrobeItem?
    @State private var selectedDress: WardrobeItem?
    @State private var selectedOuterwear: WardrobeItem?
    @State private var selectedShoes: WardrobeItem?
    @State private var selectedAccessories: [WardrobeItem] = []
    @State private var activeCategory: Category = .top
    @State private var showTryOn = false
    @State private var showSave = false
    @State private var showSettings = false
    @State private var outfitName = ""
    @State private var showDatePicker = false
    @State private var pinnedDate = Date()

    private var selectedItems: [WardrobeItem] {
        [selectedTop, selectedBottom, selectedDress, selectedOuterwear, selectedShoes]
            .compactMap { $0 } + selectedAccessories
    }

    private var categoryItems: [WardrobeItem] {
        allItems.filter { $0.category == activeCategory && $0.condition != .inStorage }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top: collage preview
                collagePreview
                    .frame(maxHeight: .infinity)

                Divider()

                // Bottom: item selector
                itemSelector
                    .frame(maxHeight: .infinity)

                // Action bar
                if !selectedItems.isEmpty {
                    actionBar
                }
            }
            .background { MeshGradientBackground() }
            .navigationTitle("Builder")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showTryOn) { TryOnView(items: selectedItems) }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .alert("Save Outfit", isPresented: $showSave) {
                TextField("Name (optional)", text: $outfitName)
                Button("Save") { saveOutfit() }
                Button("Cancel", role: .cancel) { outfitName = "" }
            }
            .sheet(isPresented: $showDatePicker) {
                NavigationStack {
                    DatePicker("Pin to Date", selection: $pinnedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                        .navigationTitle("Pin to Calendar")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Pin") {
                                    saveOutfit(planned: pinnedDate)
                                    showDatePicker = false
                                }
                                .fontWeight(.semibold)
                            }
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Cancel") { showDatePicker = false }
                            }
                        }
                }
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Collage Preview

    private var collagePreview: some View {
        ZStack {
            if selectedItems.isEmpty {
                VStack(spacing: DS.spacingMD) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 44))
                        .foregroundStyle(.quaternary)
                    Text("Pick one item per category below")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Top + Bottom + Shoes, or Dress + Shoes")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } else {
                HStack(spacing: DS.spacingSM) {
                    ForEach(selectedItems, id: \.id) { item in
                        ItemThumbnail(item: item, showConditionBadge: false)
                            .aspectRatio(0.65, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .overlay(alignment: .topTrailing) {
                                Button { removeItem(item) } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.white, .red)
                                }
                                .padding(DS.spacingXS)
                            }
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(DS.spacingLG)
                .animation(.spring(response: 0.35), value: selectedItems.map(\.id))
            }
        }
        .overlay(alignment: .topTrailing) {
            if !selectedItems.isEmpty {
                VStack(spacing: DS.spacingSM) {
                    Button { showTryOn = true } label: {
                        Label("Try On", systemImage: "person.fill")
                            .font(.caption.weight(.medium))
                    }
                    .glassPill(isSelected: true)

                    Button { clearAll() } label: {
                        Label("Clear", systemImage: "arrow.counterclockwise")
                            .font(.caption2.weight(.medium))
                    }
                    .glassPill()
                }
                .padding(DS.spacingMD)
            }
        }
    }

    // MARK: - Item Selector

    private var itemSelector: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.spacingXS) {
                    ForEach(Category.allCases) { cat in
                        GlassChip(title: cat.displayName, isSelected: activeCategory == cat) {
                            activeCategory = cat
                        }
                    }
                }
                .padding(.horizontal, DS.spacingLG)
                .padding(.vertical, DS.spacingSM)
            }

            if categoryItems.isEmpty {
                VStack(spacing: DS.spacingSM) {
                    Spacer()
                    Image(systemName: activeCategory.icon)
                        .font(.title)
                        .foregroundStyle(.quaternary)
                    Text("No \(activeCategory.displayName.lowercased()) in your closet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Add from Closet") {
                        appState.selectedTab = 0
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.accent)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: DS.gridColumns4, spacing: DS.spacingSM) {
                        ForEach(categoryItems, id: \.id) { item in
                            ItemThumbnail(item: item, showConditionBadge: false)
                                .aspectRatio(0.8, contentMode: .fit)
                                .overlay {
                                    if isSelected(item) {
                                        RoundedRectangle(cornerRadius: DS.radiusSM)
                                            .strokeBorder(Color.accentColor, lineWidth: 2.5)
                                    }
                                }
                                .onTapGesture { selectItem(item) }
                        }
                    }
                    .padding(.horizontal, DS.spacingLG)
                    .padding(.bottom, DS.spacingLG)
                }
            }
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: DS.spacingMD) {
            Button { showSave = true } label: {
                Label("Save", systemImage: "bookmark")
            }
            .buttonStyle(GlassButtonStyle())

            Menu {
                Button { showDatePicker = true } label: {
                    Label("Pin to Calendar", systemImage: "calendar.badge.plus")
                }
                Button {
                    let outfit = Outfit(itemIDs: selectedItems.map(\.id), plannedDate: Date())
                    modelContext.insert(outfit)
                    do {
                        try modelContext.save()
                        AppLog.outfit.info("Outfit added to today with \(selectedItems.count) items")
                    } catch {
                        AppLog.data.error("Failed to save outfit to today: \(error.localizedDescription)")
                    }
                    Haptic.success()
                } label: {
                    Label("Add to Today", systemImage: "sun.max")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .padding(DS.spacingLG)
        .glassBackground(cornerRadius: 0)
    }

    // MARK: - Logic

    private func isSelected(_ item: WardrobeItem) -> Bool {
        selectedItems.contains { $0.id == item.id }
    }

    private func clearAll() {
        selectedTop = nil
        selectedBottom = nil
        selectedDress = nil
        selectedOuterwear = nil
        selectedShoes = nil
        selectedAccessories = []
        Haptic.light()
    }

    private func selectItem(_ item: WardrobeItem) {
        Haptic.selection()
        switch item.category {
        case .top:
            selectedTop = selectedTop?.id == item.id ? nil : item
            if selectedTop != nil { selectedDress = nil } // Can't have dress + top
        case .bottom:
            selectedBottom = selectedBottom?.id == item.id ? nil : item
            if selectedBottom != nil { selectedDress = nil } // Can't have dress + bottom
        case .dress:
            selectedDress = selectedDress?.id == item.id ? nil : item
            if selectedDress != nil { selectedTop = nil; selectedBottom = nil } // Dress replaces top+bottom
        case .outerwear: selectedOuterwear = selectedOuterwear?.id == item.id ? nil : item
        case .shoes: selectedShoes = selectedShoes?.id == item.id ? nil : item
        case .accessory:
            if let idx = selectedAccessories.firstIndex(where: { $0.id == item.id }) {
                selectedAccessories.remove(at: idx)
            } else if selectedAccessories.count < DS.maxAccessories {
                selectedAccessories.append(item)
            }
        }
    }

    private func removeItem(_ item: WardrobeItem) {
        Haptic.light()
        switch item.category {
        case .top: selectedTop = nil
        case .bottom: selectedBottom = nil
        case .dress: selectedDress = nil
        case .outerwear: selectedOuterwear = nil
        case .shoes: selectedShoes = nil
        case .accessory: selectedAccessories.removeAll { $0.id == item.id }
        }
    }

    private func saveOutfit(planned: Date? = nil) {
        let outfit = Outfit(
            name: outfitName.isEmpty ? nil : outfitName,
            itemIDs: selectedItems.map(\.id),
            plannedDate: planned
        )
        modelContext.insert(outfit)
        do {
            try modelContext.save()
            AppLog.outfit.info("Outfit saved from Builder: \(outfit.displayName)")
        } catch {
            AppLog.data.error("Failed to save outfit from Builder: \(error.localizedDescription)")
        }
        outfitName = ""
        Haptic.success()
    }
}
