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
                    emptyState
                } else {
                    tripsList
                }
            }
            .navigationTitle("Packing")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button { showNewTrip = true } label: {
                            Image(systemName: "plus")
                        }
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .sheet(isPresented: $showNewTrip) {
                TripSetupView(allItems: items)
            }
            .sheet(item: $selectedTrip) { trip in
                PackingResultsView(trip: trip, allItems: items)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "suitcase")
                .font(.system(size: 60))
                .foregroundStyle(.quaternary)
            Text("Plan your next trip packing list.")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button("Start a Trip") { showNewTrip = true }
                .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    private var tripsList: some View {
        List(trips, id: \.id) { trip in
            Button {
                selectedTrip = trip
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.name.isEmpty ? trip.destination : trip.name)
                        .font(.headline)
                    Text(trip.destination)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        let formatter = DateFormatter()
                        Text({
                            formatter.dateStyle = .short
                            return "\(formatter.string(from: trip.startDate)) - \(formatter.string(from: trip.endDate))"
                        }())
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(trip.packedItemIDs.count) items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    FlowLayout(spacing: 4) {
                        ForEach(trip.activities, id: \.self) { activity in
                            Text(activity.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray5))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    modelContext.delete(trip)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .listStyle(.plain)
    }
}

struct TripSetupView: View {
    let allItems: [WardrobeItem]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var destination = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var selectedActivities: Set<Activity> = []
    @State private var tripName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    TextField("Destination", text: $destination)
                    TextField("Trip Name (optional)", text: $tripName)
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                }

                Section("Activities") {
                    FlowLayout(spacing: 8) {
                        ForEach(Activity.allCases, id: \.self) { activity in
                            FilterChip(
                                title: activity.displayName,
                                isSelected: selectedActivities.contains(activity),
                                onTap: {
                                    if selectedActivities.contains(activity) {
                                        selectedActivities.remove(activity)
                                    } else {
                                        selectedActivities.insert(activity)
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Build List") {
                        buildPackingList()
                    }
                    .fontWeight(.semibold)
                    .disabled(destination.isEmpty)
                }
            }
        }
    }

    private func buildPackingList() {
        let trip = PackingTrip(
            name: tripName.isEmpty ? destination : tripName,
            destination: destination,
            startDate: startDate,
            endDate: endDate,
            activities: Array(selectedActivities)
        )

        // Auto-select items based on activities
        let suggestedItems = suggestPackingItems()
        trip.packedItemIDs = suggestedItems.map(\.id)

        modelContext.insert(trip)
        try? modelContext.save()
        dismiss()
    }

    private func suggestPackingItems() -> [WardrobeItem] {
        let numberOfDays = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 3
        var selected: [WardrobeItem] = []

        let available = allItems.filter { $0.condition == .clean }

        // Determine needed formalities based on activities
        var neededFormalities: Set<Formality> = [.casual]
        for activity in selectedActivities {
            switch activity {
            case .businessMeetings, .formalEvents, .fineDining:
                neededFormalities.insert(.formal)
                neededFormalities.insert(.smartCasual)
            case .hiking, .active, .beach:
                neededFormalities.insert(.athletic)
                neededFormalities.insert(.casual)
            case .cityExploring, .casualDinners:
                neededFormalities.insert(.casual)
                neededFormalities.insert(.smartCasual)
            }
        }

        // Select tops (more than bottoms for variety)
        let tops = available.filter { $0.category == .top && neededFormalities.contains($0.formality) }
        let topCount = min(tops.count, max(3, numberOfDays))
        selected.append(contentsOf: tops.prefix(topCount))

        // Select bottoms (fewer, for mix-and-match)
        let bottoms = available.filter { $0.category == .bottom && neededFormalities.contains($0.formality) }
        let bottomCount = min(bottoms.count, max(2, numberOfDays / 2 + 1))
        selected.append(contentsOf: bottoms.prefix(bottomCount))

        // Dresses if relevant
        if selectedActivities.contains(.fineDining) || selectedActivities.contains(.formalEvents) {
            let dresses = available.filter { $0.category == .dress }
            selected.append(contentsOf: dresses.prefix(1))
        }

        // Outerwear
        let outerwear = available.filter { $0.category == .outerwear }
        selected.append(contentsOf: outerwear.prefix(1))

        // Shoes
        let shoes = available.filter { $0.category == .shoes }
        selected.append(contentsOf: shoes.prefix(min(2, shoes.count)))

        return selected
    }
}

struct PackingResultsView: View {
    @Bindable var trip: PackingTrip
    let allItems: [WardrobeItem]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showChecklist = false

    private var packedItems: [WardrobeItem] {
        trip.packedItemIDs.compactMap { id in
            allItems.first(where: { $0.id == id })
        }
    }

    private var groupedItems: [(Category, [WardrobeItem])] {
        let grouped = Dictionary(grouping: packedItems) { $0.category }
        return Category.allCases.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return (category, items)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Toggle
                Toggle("View as Checklist", isOn: $showChecklist)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                if showChecklist {
                    checklistView
                } else {
                    itemsView
                }
            }
            .navigationTitle(trip.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var itemsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Trip info
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.destination)
                        .font(.headline)
                    let formatter = DateFormatter()
                    Text({
                        formatter.dateStyle = .medium
                        return "\(formatter.string(from: trip.startDate)) - \(formatter.string(from: trip.endDate))"
                    }())
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text("\(trip.numberOfDays) days, \(packedItems.count) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                // Items by category
                ForEach(groupedItems, id: \.0) { category, categoryItems in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(category.displayName)
                            .font(.headline)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(categoryItems, id: \.id) { item in
                                    VStack(spacing: 4) {
                                        ItemThumbnail(item: item, size: 80)
                                        Text(item.name ?? item.subcategory.capitalized)
                                            .font(.caption2)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                // Combinations
                VStack(alignment: .leading, spacing: 8) {
                    let tops = packedItems.filter { $0.category == .top }
                    let bottoms = packedItems.filter { $0.category == .bottom }

                    if !tops.isEmpty && !bottoms.isEmpty {
                        Text("Possible Combinations: \(tops.count * bottoms.count)")
                            .font(.headline)
                            .padding(.horizontal)

                        Text("Mix and match your \(tops.count) tops with \(bottoms.count) bottoms")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }

    private var checklistView: some View {
        List {
            ForEach(groupedItems, id: \.0) { category, categoryItems in
                Section(category.displayName) {
                    ForEach(categoryItems, id: \.id) { item in
                        ChecklistRow(item: item)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct ChecklistRow: View {
    let item: WardrobeItem
    @State private var isChecked = false

    var body: some View {
        HStack {
            Button {
                isChecked.toggle()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChecked ? .green : .secondary)
            }

            Text(item.name ?? item.subcategory.capitalized)
                .strikethrough(isChecked)
                .foregroundStyle(isChecked ? .secondary : .primary)

            Spacer()

            Text(item.primaryColor.capitalized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
