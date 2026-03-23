import SwiftUI
import SwiftData

struct AddItemMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showBatch = false
    @State private var showSingle = false
    @State private var showOnline = false

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.spacingMD) {
                ImportCard(
                    icon: "camera.viewfinder",
                    title: "Batch Photo",
                    description: "Photograph a pile of clothes, we'll separate them"
                ) { showBatch = true }

                ImportCard(
                    icon: "camera",
                    title: "Single Item",
                    description: "Add one piece at a time"
                ) { showSingle = true }

                ImportCard(
                    icon: "magnifyingglass",
                    title: "Search Online",
                    description: "Find an item by brand/name and import the product image"
                ) { showOnline = true }

                Spacer()
            }
            .padding(DS.spacingLG)
            .background { MeshGradientBackground() }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showBatch) { AddItemBatchView() }
            .sheet(isPresented: $showSingle) { AddItemSingleView() }
            .sheet(isPresented: $showOnline) { OnlineSearchView() }
        }
    }
}

// MARK: - Common Subcategory Suggestions

private let subcategorySuggestions: [Category: [String]] = [
    .top: ["T-Shirt", "Blouse", "Button-Down", "Sweater", "Tank Top", "Polo", "Hoodie", "Crop Top", "Henley", "Turtleneck"],
    .bottom: ["Jeans", "Chinos", "Trousers", "Shorts", "Skirt", "Leggings", "Joggers", "Cargo Pants", "Dress Pants"],
    .dress: ["Maxi Dress", "Mini Dress", "Midi Dress", "Sundress", "Cocktail Dress", "Wrap Dress", "Shift Dress"],
    .outerwear: ["Jacket", "Blazer", "Coat", "Cardigan", "Puffer", "Windbreaker", "Denim Jacket", "Leather Jacket", "Trench Coat"],
    .shoes: ["Sneakers", "Boots", "Sandals", "Loafers", "Heels", "Flats", "Oxford", "Running Shoes", "Slides"],
    .accessory: ["Watch", "Necklace", "Earrings", "Belt", "Hat", "Sunglasses", "Scarf", "Bracelet", "Ring", "Bag"]
]

// MARK: - Single Item

struct AddItemSingleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var capturedImage: UIImage?
    @State private var showCamera = true
    @State private var isProcessing = false
    @State private var autoTagged = false
    @State private var errorMessage: String?

    @State private var category: Category = .top
    @State private var subcategory = ""
    @State private var primaryColor = ""
    @State private var secondaryColor = ""
    @State private var pattern: Pattern = .solid
    @State private var material: Material = .unknown
    @State private var formality: Formality = .casual
    @State private var selectedSeasons: Set<Season> = [.yearRound]

    var body: some View {
        NavigationStack {
            Group {
                if showCamera {
                    VStack {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.yellow)
                            Text("Fill the frame with the item against a plain background")
                                .font(.subheadline)
                        }
                        .padding()
                        .glassBackground(cornerRadius: DS.radiusMD)
                        .padding(.horizontal)

                        ImagePicker(image: $capturedImage, sourceType: .camera)
                    }
                    .onChange(of: capturedImage) { _, newVal in
                        if newVal != nil {
                            showCamera = false
                            processImage()
                        }
                    }
                } else if isProcessing {
                    GlassProgressView(title: "Analyzing your item...", subtitle: "Removing background & detecting details")
                } else {
                    reviewForm
                }
            }
            .background { MeshGradientBackground() }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var reviewForm: some View {
        ScrollView {
            VStack(spacing: DS.spacingLG) {
                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: DS.radiusLG))
                        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                }

                if let error = errorMessage {
                    HStack(spacing: DS.spacingSM) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                    }
                    .glassCard(cornerRadius: DS.radiusMD)
                }

                // Quick accept if auto-tagged
                if autoTagged {
                    Button(action: saveItem) {
                        Label("Looks Good — Add to Closet", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(GlassButtonStyle())

                    Text("or edit details below")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Editable fields
                VStack(spacing: DS.spacingMD) {
                    Picker("Category", selection: $category) {
                        ForEach(Category.allCases) { c in Text(c.displayName).tag(c) }
                    }
                    .onChange(of: category) { _, _ in
                        if subcategory.isEmpty || !currentSuggestions.map({ $0.lowercased() }).contains(subcategory.lowercased()) {
                            subcategory = ""
                        }
                    }

                    // Subcategory with suggestions
                    VStack(alignment: .leading, spacing: DS.spacingSM) {
                        HStack {
                            Text("Type")
                            Spacer()
                            TextField("e.g. t-shirt", text: $subcategory)
                                .multilineTextAlignment(.trailing)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DS.spacingXS) {
                                ForEach(currentSuggestions, id: \.self) { suggestion in
                                    Button {
                                        subcategory = suggestion.lowercased()
                                        Haptic.selection()
                                    } label: {
                                        Text(suggestion)
                                            .font(.caption)
                                            .glassPill(isSelected: subcategory.lowercased() == suggestion.lowercased())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    HStack {
                        Text("Color")
                        Spacer()
                        TextField("Primary color", text: $primaryColor)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Secondary Color")
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("Optional", text: $secondaryColor)
                            .multilineTextAlignment(.trailing)
                    }

                    Picker("Pattern", selection: $pattern) {
                        ForEach(Pattern.allCases, id: \.self) { p in Text(p.displayName).tag(p) }
                    }

                    Picker("Material", selection: $material) {
                        ForEach(Material.allCases, id: \.self) { m in Text(m.displayName).tag(m) }
                    }

                    Picker("Formality", selection: $formality) {
                        ForEach(Formality.allCases, id: \.self) { f in Text(f.displayName).tag(f) }
                    }
                }
                .glassCard()

                if !autoTagged {
                    Button(action: saveItem) {
                        Text("Add to Closet")
                    }
                    .buttonStyle(GlassButtonStyle())
                }
            }
            .padding(DS.spacingLG)
        }
    }

    private var currentSuggestions: [String] {
        subcategorySuggestions[category] ?? []
    }

    private func processImage() {
        guard let image = capturedImage else { return }
        isProcessing = true

        Task {
            let cleanImage = await ImageService.shared.removeBackground(from: image)
            await MainActor.run { capturedImage = cleanImage }

            do {
                let result = try await GeminiVisionService().tagSingleItem(image: cleanImage)
                await MainActor.run {
                    category = Category(rawValue: result.category) ?? .top
                    subcategory = result.subcategory
                    primaryColor = result.primaryColor
                    secondaryColor = result.secondaryColor ?? ""
                    pattern = Pattern(rawValue: result.pattern) ?? .solid
                    material = Material(rawValue: result.materialEstimate) ?? .unknown
                    formality = Formality(rawValue: result.formality) ?? .casual
                    selectedSeasons = Set(result.season.compactMap { Season(rawValue: $0) })
                    autoTagged = true
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    autoTagged = false
                    isProcessing = false
                }
            }
        }
    }

    private func saveItem() {
        let item = WardrobeItem(
            category: category,
            subcategory: subcategory.isEmpty ? category.rawValue : subcategory,
            primaryColor: primaryColor.isEmpty ? "Unknown" : primaryColor,
            secondaryColor: secondaryColor.isEmpty ? nil : secondaryColor,
            pattern: pattern,
            materialEstimate: material,
            formality: formality,
            seasons: Array(selectedSeasons)
        )

        if let image = capturedImage {
            try? ImageService.shared.saveItemPhoto(image, fileName: item.photoFileName)
        }

        modelContext.insert(item)
        try? modelContext.save()
        Haptic.success()

        // Post notification for toast
        NotificationCenter.default.post(name: .itemAdded, object: item.displayName)
        dismiss()
    }
}

// MARK: - Batch

struct AddItemBatchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var capturedImage: UIImage?
    @State private var showCamera = true
    @State private var isProcessing = false
    @State private var detectedItems: [DetectedItem] = []
    @State private var errorMessage: String?

    struct DetectedItem: Identifiable {
        let id = UUID()
        var image: UIImage
        var category: Category
        var primaryColor: String
        var pattern: Pattern
        var material: Material
        var formality: Formality
        var isSelected = true
    }

    var body: some View {
        NavigationStack {
            Group {
                if showCamera {
                    VStack {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.yellow)
                            Text("Lay clothes flat with space between items")
                                .font(.subheadline)
                        }
                        .padding()
                        .glassBackground(cornerRadius: DS.radiusMD)
                        .padding(.horizontal)

                        ImagePicker(image: $capturedImage, sourceType: .camera)
                    }
                    .onChange(of: capturedImage) { _, newVal in
                        if newVal != nil {
                            showCamera = false
                            processBatch()
                        }
                    }
                } else if isProcessing {
                    GlassProgressView(title: "Finding your clothes...", subtitle: "Detecting and separating each item")
                } else if detectedItems.isEmpty && errorMessage != nil {
                    VStack(spacing: DS.spacingLG) {
                        EmptyStateView(
                            icon: "exclamationmark.triangle",
                            title: "Couldn't detect items",
                            subtitle: errorMessage ?? "Try again with better lighting.",
                            actionTitle: "Try Again",
                            action: { showCamera = true; capturedImage = nil }
                        )
                    }
                } else {
                    reviewGrid
                }
            }
            .background { MeshGradientBackground() }
            .navigationTitle("Batch Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var reviewGrid: some View {
        VStack(spacing: 0) {
            // Header with select all
            HStack {
                let count = detectedItems.filter(\.isSelected).count
                Text("\(count) of \(detectedItems.count) selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(count == detectedItems.count ? "Deselect All" : "Select All") {
                    let newState = count < detectedItems.count
                    for i in detectedItems.indices { detectedItems[i].isSelected = newState }
                    Haptic.selection()
                }
                .font(.caption.weight(.medium))
            }
            .padding(.horizontal, DS.spacingLG)
            .padding(.vertical, DS.spacingSM)

            ScrollView {
                LazyVGrid(columns: DS.gridColumns2, spacing: DS.spacingMD) {
                    ForEach($detectedItems) { $item in
                        VStack(spacing: DS.spacingSM) {
                            Image(uiImage: item.image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: DS.radiusSM))
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        item.isSelected.toggle()
                                        Haptic.selection()
                                    } label: {
                                        Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(item.isSelected ? .green : .secondary)
                                            .font(.title3)
                                            .padding(DS.spacingXS)
                                    }
                                }
                                .opacity(item.isSelected ? 1 : 0.5)

                            Text(item.category.displayName).font(.caption.weight(.medium))
                            Text(item.primaryColor).font(.caption2).foregroundStyle(.secondary)
                        }
                        .glassCard(cornerRadius: DS.radiusMD)
                    }
                }
                .padding(DS.spacingLG)
            }

            let count = detectedItems.filter(\.isSelected).count
            Button { saveItems() } label: {
                Text("Add \(count) item\(count == 1 ? "" : "s") to Closet")
            }
            .buttonStyle(GlassButtonStyle())
            .disabled(count == 0)
            .opacity(count > 0 ? 1 : 0.5)
            .padding(DS.spacingLG)
        }
    }

    private func processBatch() {
        guard let image = capturedImage else { return }
        isProcessing = true

        Task {
            do {
                let results = try await GeminiVisionService().detectBatchItems(image: image)
                var detected: [DetectedItem] = []

                for bi in results {
                    let cropRect = CGRect(
                        x: bi.boundingBox.x * Double(image.size.width),
                        y: bi.boundingBox.y * Double(image.size.height),
                        width: bi.boundingBox.width * Double(image.size.width),
                        height: bi.boundingBox.height * Double(image.size.height)
                    )
                    if let cg = image.cgImage?.cropping(to: cropRect) {
                        var cropped = UIImage(cgImage: cg)
                        cropped = await ImageService.shared.removeBackground(from: cropped)
                        detected.append(DetectedItem(
                            image: cropped,
                            category: Category(rawValue: bi.category) ?? .top,
                            primaryColor: bi.primaryColor,
                            pattern: Pattern(rawValue: bi.pattern) ?? .solid,
                            material: Material(rawValue: bi.materialEstimate) ?? .unknown,
                            formality: Formality(rawValue: bi.formality) ?? .casual
                        ))
                    }
                }

                await MainActor.run {
                    detectedItems = detected
                    isProcessing = false
                    if detected.isEmpty {
                        errorMessage = "No items detected. Try with better lighting or spacing."
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Could not detect items. Try adding individually."
                    isProcessing = false
                }
            }
        }
    }

    private func saveItems() {
        let selected = detectedItems.filter(\.isSelected)
        for d in selected {
            let item = WardrobeItem(
                category: d.category,
                subcategory: d.category.rawValue,
                primaryColor: d.primaryColor,
                pattern: d.pattern,
                materialEstimate: d.material,
                formality: d.formality
            )
            try? ImageService.shared.saveItemPhoto(d.image, fileName: item.photoFileName)
            modelContext.insert(item)
        }
        try? modelContext.save()
        Haptic.success()
        NotificationCenter.default.post(name: .itemAdded, object: "\(selected.count) items")
        dismiss()
    }
}

// MARK: - Online Search

struct OnlineSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchQuery = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.spacingXL) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 100, height: 100)
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: DS.spacingSM) {
                    Text("Coming Soon")
                        .font(.title3.weight(.semibold))
                    Text("Search clothing by brand and name to import product images directly.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.spacingXXL)
                }

                Text("Use Single Item or Batch Photo for now")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()
            }
            .background { MeshGradientBackground() }
            .navigationTitle("Search Online")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let itemAdded = Notification.Name("itemAdded")
}
