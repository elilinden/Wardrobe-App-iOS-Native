import SwiftUI
import SwiftData

struct PackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PackingTrip.startDate, order: .reverse) private var trips: [PackingTrip]
    @Query(filter: #Predicate<WardrobeItem> { !$0.isWishlist }) private var items: [WardrobeItem]

    @State private var showNewTrip = false
    @State private var selectedTrip: PackingTrip?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty {
                    EmptyStateView(
                        icon: "suitcase",
                        title: "Plan your next trip",
                        subtitle: "Build a smart packing list based on your destination and activities.",
                        actionTitle: "Start a Trip",
                        action: { showNewTrip = true }
                    )
                } else {
                    tripList
                }
            }
            .background { MeshGradientBackground() }
            .navigationTitle("Packing")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: DS.spacingMD) {
                        Button { showNewTrip = true } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .sheet(isPresented: $showNewTrip) { TripSetupView(allItems: items) }
            .sheet(item: $selectedTrip) { trip in PackingResultsView(trip: trip, allItems: items) }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    private var tripList: some View {
        ScrollView {
            LazyVStack(spacing: DS.spacingMD) {
                ForEach(trips, id: \.id) { trip in
                    Button { selectedTrip = trip } label: {
                        VStack(alignment: .leading, spacing: DS.spacingSM) {
                            HStack {
                                VStack(alignment: .leading, spacing: DS.spacingXS) {
                                    Text(trip.displayName)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(trip.destination)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: DS.spacingXS) {
                                    Text("\(trip.numberOfDays) days")
                                        .font(.caption.weight(.medium))
                                    Text("\(trip.packedItemIDs.count) items")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text(trip.dateRangeFormatted)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            FlowLayout(spacing: DS.spacingXS) {
                                ForEach(trip.activities, id: \.self) { activity in
                                    HStack(spacing: DS.spacingXS) {
                                        Image(systemName: activity.icon)
                                            .font(.caption2)
                                        Text(activity.displayName)
                                    }
                                    .font(.caption2)
                                    .glassPill()
                                }
                            }
                        }
                        .glassCard()
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            AppLog.packing.info("Deleting trip: \(trip.displayName)")
                            modelContext.delete(trip)
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
            .padding(DS.spacingLG)
        }
    }
}

// MARK: - Trip Setup

struct TripSetupView: View {
    let allItems: [WardrobeItem]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var destination = ""
    @State private var tripName = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var selectedActivities: Set<Activity> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.spacingXL) {
                    VStack(spacing: DS.spacingMD) {
                        VStack(alignment: .leading, spacing: DS.spacingSM) {
                            HStack {
                                Text("Destination").font(.caption).foregroundStyle(.secondary)
                                Text("Required").font(.caption2).foregroundStyle(.red)
                            }
                            TextField("City or country", text: $destination)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: DS.spacingSM) {
                            Text("Trip Name").font(.caption).foregroundStyle(.secondary)
                            TextField("Optional", text: $tripName)
                                .textFieldStyle(.roundedBorder)
                        }

                        DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                    .glassCard()

                    VStack(alignment: .leading, spacing: DS.spacingMD) {
                        VStack(alignment: .leading, spacing: DS.spacingXS) {
                            Text("Activities").font(.headline)
                            Text("Optional — select to personalize your packing list")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        GlassMultiChipSelector(
                            options: Activity.allCases.map { ($0.displayName, $0) },
                            selected: $selectedActivities
                        )
                    }
                    .glassCard()

                    Button(action: buildList) {
                        Label("Build My Packing List", systemImage: "suitcase")
                    }
                    .buttonStyle(GlassButtonStyle())
                    .disabled(destination.isEmpty)
                    .opacity(destination.isEmpty ? 0.5 : 1)
                }
                .padding(DS.spacingLG)
            }
            .background { MeshGradientBackground() }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func buildList() {
        let trip = PackingTrip(
            name: tripName.isEmpty ? destination : tripName,
            destination: destination,
            startDate: startDate,
            endDate: endDate,
            activities: Array(selectedActivities)
        )

        let suggested = suggestItems(for: trip)
        trip.packedItemIDs = suggested.map(\.id)

        modelContext.insert(trip)
        do {
            try modelContext.save()
            AppLog.packing.info("Trip created: \(trip.displayName) with \(suggested.count) items")
        } catch {
            AppLog.data.error("Failed to save trip: \(error.localizedDescription)")
        }
        Haptic.success()
        dismiss()
    }

    private func suggestItems(for trip: PackingTrip) -> [WardrobeItem] {
        let available = allItems.filter { $0.condition == .clean }
        let days = trip.numberOfDays
        var selected: [WardrobeItem] = []

        var needed: Set<Formality> = [.casual]
        for activity in selectedActivities {
            needed.formUnion(activity.requiredFormalities)
        }

        let tops = available.filter { $0.category == .top && needed.contains($0.formality) }
        selected.append(contentsOf: tops.prefix(min(tops.count, max(3, days))))

        let bottoms = available.filter { $0.category == .bottom && needed.contains($0.formality) }
        selected.append(contentsOf: bottoms.prefix(min(bottoms.count, max(2, days / 2 + 1))))

        if selectedActivities.contains(.fineDining) || selectedActivities.contains(.formalEvents) {
            let dresses = available.filter { $0.category == .dress }
            selected.append(contentsOf: dresses.prefix(1))
        }

        let outerwear = available.filter { $0.category == .outerwear }
        selected.append(contentsOf: outerwear.prefix(1))

        let shoes = available.filter { $0.category == .shoes }
        selected.append(contentsOf: shoes.prefix(min(2, shoes.count)))

        return selected
    }
}

// MARK: - Packing Results

struct PackingResultsView: View {
    @Bindable var trip: PackingTrip
    let allItems: [WardrobeItem]
    @Environment(\.dismiss) private var dismiss
    @State private var viewMode: PackingViewMode = .detail
    @State private var checkedItems: Set<UUID> = []

    enum PackingViewMode: String, CaseIterable {
        case detail = "Detail"
        case checklist = "Checklist"
    }

    private var packedItems: [WardrobeItem] {
        trip.packedItemIDs.compactMap { id in allItems.first { $0.id == id } }
    }

    private var grouped: [(Category, [WardrobeItem])] {
        let dict = Dictionary(grouping: packedItems) { $0.category }
        return Category.allCases.compactMap { cat in
            guard let items = dict[cat], !items.isEmpty else { return nil }
            return (cat, items)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented mode picker
                Picker("View", selection: $viewMode) {
                    ForEach(PackingViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, DS.spacingLG)
                .padding(.vertical, DS.spacingSM)

                if viewMode == .checklist {
                    VStack {
                        checklistView

                        // Packed count summary
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Packed \(checkedItems.count) of \(packedItems.count) items")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            if checkedItems.count == packedItems.count && !packedItems.isEmpty {
                                Text("All packed!")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(DS.spacingLG)
                        .glassBackground(cornerRadius: 0)
                    }
                } else {
                    detailView
                }
            }
            .background { MeshGradientBackground() }
            .navigationTitle(trip.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var detailView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.spacingXL) {
                // Trip info
                VStack(alignment: .leading, spacing: DS.spacingSM) {
                    Label(trip.destination, systemImage: "mappin.and.ellipse")
                        .font(.headline)
                    Text(trip.dateRangeFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(trip.numberOfDays) days · \(packedItems.count) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .glassCard()

                // Items by category
                ForEach(grouped, id: \.0) { category, categoryItems in
                    VStack(alignment: .leading, spacing: DS.spacingSM) {
                        Text(category.displayName).font(.headline)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DS.spacingMD) {
                                ForEach(categoryItems, id: \.id) { item in
                                    VStack(spacing: DS.spacingXS) {
                                        ItemThumbnail(item: item, size: 72, showConditionBadge: false)
                                        Text(item.displayName)
                                            .font(.caption2)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }

                // Combinations
                let tops = packedItems.filter { $0.category == .top }
                let bottoms = packedItems.filter { $0.category == .bottom }
                if !tops.isEmpty && !bottoms.isEmpty {
                    VStack(alignment: .leading, spacing: DS.spacingSM) {
                        Text("Outfit Combinations")
                            .font(.headline)
                        Text("Mix \(tops.count) tops with \(bottoms.count) bottoms = \(tops.count * bottoms.count) outfits")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .glassCard()
                }
            }
            .padding(DS.spacingLG)
        }
    }

    private var checklistView: some View {
        List {
            ForEach(grouped, id: \.0) { category, categoryItems in
                Section(category.displayName) {
                    ForEach(categoryItems, id: \.id) { item in
                        PackingChecklistRow(item: item, checkedItems: $checkedItems)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}

struct PackingChecklistRow: View {
    let item: WardrobeItem
    @Binding var checkedItems: Set<UUID>

    private var isChecked: Bool { checkedItems.contains(item.id) }

    var body: some View {
        HStack(spacing: DS.spacingMD) {
            Button {
                if isChecked {
                    checkedItems.remove(item.id)
                } else {
                    checkedItems.insert(item.id)
                }
                Haptic.light()
            } label: {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChecked ? .green : .secondary)
                    .font(.title3)
            }

            Text(item.displayName)
                .strikethrough(isChecked)
                .foregroundStyle(isChecked ? .secondary : .primary)

            Spacer()

            Text(item.primaryColor.capitalized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .listRowBackground(Color.clear)
    }
}
