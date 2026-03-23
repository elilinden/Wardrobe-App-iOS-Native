import SwiftUI
import SwiftData

enum LookbookFilter: String, CaseIterable {
    case all = "All"
    case favorites = "Favorites"
    case calendar = "Calendar"
}

struct LookbookView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Outfit.createdDate, order: .reverse) private var outfits: [Outfit]
    @Query private var items: [WardrobeItem]

    @State private var filter: LookbookFilter = .all
    @State private var selectedOutfit: Outfit?
    @State private var showSettings = false

    private var filteredOutfits: [Outfit] {
        switch filter {
        case .all:
            return outfits
        case .favorites:
            return outfits.filter(\.isFavorite)
        case .calendar:
            return outfits // Calendar view handles its own filtering
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                Picker("", selection: $filter) {
                    ForEach(LookbookFilter.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                if filter == .calendar {
                    CalendarLookbookView(outfits: outfits, items: items)
                } else if filteredOutfits.isEmpty {
                    emptyState
                } else {
                    gridView
                }
            }
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
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundStyle(.quaternary)
            Text("Save outfits here for inspiration later.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            NavigationLink {
                BuilderView()
            } label: {
                Text("Go to Builder")
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(filteredOutfits, id: \.id) { outfit in
                    OutfitCardView(outfit: outfit, allItems: items)
                        .onTapGesture { selectedOutfit = outfit }
                        .contextMenu {
                            Button {
                                outfit.isFavorite.toggle()
                            } label: {
                                Label(
                                    outfit.isFavorite ? "Unfavorite" : "Favorite",
                                    systemImage: outfit.isFavorite ? "heart.slash" : "heart"
                                )
                            }

                            Button(role: .destructive) {
                                modelContext.delete(outfit)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding()
        }
    }
}

struct OutfitCardView: View {
    let outfit: Outfit
    let allItems: [WardrobeItem]

    private var outfitItems: [WardrobeItem] {
        outfit.itemIDs.compactMap { id in
            allItems.first(where: { $0.id == id })
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if let renderURL = outfit.tryOnRenderURL,
                   let image = ImageService.shared.loadImage(from: renderURL) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    // Flat lay collage
                    HStack(spacing: 2) {
                        ForEach(outfitItems.prefix(3), id: \.id) { item in
                            ItemThumbnail(item: item, size: nil)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topTrailing) {
                if outfit.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .padding(8)
                }
            }

            Text(outfit.name ?? "Outfit")
                .font(.caption)
                .lineLimit(1)

            if let occasion = outfit.occasion {
                Text(occasion.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct OutfitDetailView: View {
    @Bindable var outfit: Outfit
    let allItems: [WardrobeItem]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showTryOn = false
    @State private var showDeleteConfirmation = false

    private var outfitItems: [WardrobeItem] {
        outfit.itemIDs.compactMap { id in
            allItems.first(where: { $0.id == id })
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Main image
                    if let renderURL = outfit.tryOnRenderURL,
                       let image = ImageService.shared.loadImage(from: renderURL) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 400)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        HStack(spacing: 8) {
                            ForEach(outfitItems, id: \.id) { item in
                                ItemThumbnail(item: item, size: nil)
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(0.7, contentMode: .fit)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // Item list
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Items")
                            .font(.headline)

                        ForEach(outfitItems, id: \.id) { item in
                            HStack {
                                ItemThumbnail(item: item, size: 40)
                                Text(item.name ?? item.subcategory.capitalized)
                                    .font(.subheadline)
                                Spacer()
                                Text(item.category.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Tags
                    HStack(spacing: 8) {
                        if let occasion = outfit.occasion {
                            TagPill(text: occasion.displayName, color: .blue)
                        }
                        if let season = outfit.season {
                            TagPill(text: season.displayName, color: .teal)
                        }
                    }
                    .padding(.horizontal)

                    // Notes
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Add notes...", text: Binding(
                            get: { outfit.name ?? "" },
                            set: { outfit.name = $0 }
                        ))
                    }
                    .padding(.horizontal)

                    // Worn dates
                    if !outfit.wornDates.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Worn on")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(outfit.wornDates, id: \.self) { date in
                                let formatter = DateFormatter()
                                Text({
                                    formatter.dateStyle = .medium
                                    return formatter.string(from: date)
                                }())
                                .font(.caption)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Actions
                    VStack(spacing: 12) {
                        Button {
                            outfit.wornDates.append(Date())
                            // Mark all items as worn
                            for item in outfitItems {
                                item.timesWorn += 1
                                item.lastWorn = Date()
                            }
                            try? modelContext.save()
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            Label("Wear Again", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button { showTryOn = true } label: {
                            Label("Try On", systemImage: "person.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            outfit.isFavorite.toggle()
                        } label: {
                            Label(
                                outfit.isFavorite ? "Unfavorite" : "Favorite",
                                systemImage: outfit.isFavorite ? "heart.fill" : "heart"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(outfit.name ?? "Outfit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showTryOn) {
                TryOnView(items: outfitItems)
            }
            .alert("Delete this outfit?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    modelContext.delete(outfit)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

struct CalendarLookbookView: View {
    let outfits: [Outfit]
    let items: [WardrobeItem]

    @State private var selectedDate = Date()
    @State private var selectedMonth = Date()

    private var calendar: Calendar { Calendar.current }

    private var datesWithOutfits: Set<DateComponents> {
        var dates = Set<DateComponents>()
        for outfit in outfits {
            for wornDate in outfit.wornDates {
                let components = calendar.dateComponents([.year, .month, .day], from: wornDate)
                dates.insert(components)
            }
            if let planned = outfit.plannedDate {
                let components = calendar.dateComponents([.year, .month, .day], from: planned)
                dates.insert(components)
            }
        }
        return dates
    }

    private var outfitsForSelectedDate: [Outfit] {
        let selectedComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        return outfits.filter { outfit in
            let wornMatch = outfit.wornDates.contains { date in
                calendar.dateComponents([.year, .month, .day], from: date) == selectedComponents
            }
            let plannedMatch = outfit.plannedDate.map {
                calendar.dateComponents([.year, .month, .day], from: $0) == selectedComponents
            } ?? false
            return wornMatch || plannedMatch
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding(.horizontal)

                if outfitsForSelectedDate.isEmpty {
                    Text("No outfits for this date")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    ForEach(outfitsForSelectedDate, id: \.id) { outfit in
                        OutfitCardView(outfit: outfit, allItems: items)
                            .padding(.horizontal)
                    }
                }
            }
        }
    }
}
