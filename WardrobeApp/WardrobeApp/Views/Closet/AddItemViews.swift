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

// MARK: - Single Item

struct AddItemSingleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var capturedImage: UIImage?
    @State private var showCamera = true
    @State private var isProcessing = false
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
                        Text("Fill the frame with the item")
                            .font(.headline)
                            .padding()
                        ImagePicker(image: $capturedImage, sourceType: .camera)
                    }
                    .onChange(of: capturedImage) { _, newVal in
                        if newVal != nil {
                            showCamera = false
                            processImage()
                        }
                    }
                } else if isProcessing {
                    GlassProgressView(title: "Analyzing your item...", subtitle: "Removing background & auto-tagging")
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
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: DS.radiusLG))
                        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .glassCard(cornerRadius: DS.radiusMD)
                }

                VStack(spacing: DS.spacingMD) {
                    Picker("Category", selection: $category) {
                        ForEach(Category.allCases) { c in Text(c.displayName).tag(c) }
                    }

                    HStack {
                        Text("Subcategory")
                        Spacer()
                        TextField("e.g. t-shirt, blazer", text: $subcategory)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Primary Color")
                        Spacer()
                        TextField("Color", text: $primaryColor)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Secondary Color")
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

                Button(action: saveItem) {
                    Text("Add to Closet")
                }
                .buttonStyle(GlassButtonStyle())
            }
            .padding(DS.spacingLG)
        }
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
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isProcessing = false
                }
            }
        }
    }

    private func saveItem() {
        let item = WardrobeItem(
            category: category,
            subcategory: subcategory,
            primaryColor: primaryColor,
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
                        Text("Lay clothes flat and photograph the pile")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding()
                        ImagePicker(image: $capturedImage, sourceType: .camera)
                    }
                    .onChange(of: capturedImage) { _, newVal in
                        if newVal != nil {
                            showCamera = false
                            processBatch()
                        }
                    }
                } else if isProcessing {
                    GlassProgressView(title: "Finding your clothes...", subtitle: "Detecting and separating items")
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
        VStack {
            if let error = errorMessage {
                Text(error).foregroundStyle(.orange).font(.caption).padding()
            }

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

                            Text(item.category.displayName).font(.caption)
                            Text(item.primaryColor).font(.caption2).foregroundStyle(.secondary)
                        }
                        .glassCard(cornerRadius: DS.radiusMD)
                    }
                }
                .padding(DS.spacingLG)
            }

            let count = detectedItems.filter(\.isSelected).count
            Button { saveItems() } label: {
                Text("Add \(count) items to Closet")
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
        for d in detectedItems where d.isSelected {
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
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "Search Online",
                    subtitle: "Search for clothing items by brand and name. This feature requires a product image search API integration."
                )
                Spacer()
            }
            .background { MeshGradientBackground() }
            .searchable(text: $searchQuery, prompt: "e.g. Zara linen blazer cream")
            .navigationTitle("Search Online")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
