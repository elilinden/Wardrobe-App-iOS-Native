import SwiftUI
import SwiftData

struct AddItemMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showBatch = false
    @State private var showSingle = false
    @State private var showOnline = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ImportOptionCard(
                    icon: "camera.viewfinder",
                    title: "Batch Photo",
                    description: "Photograph a pile of clothes, we'll separate them",
                    action: { showBatch = true }
                )

                ImportOptionCard(
                    icon: "camera",
                    title: "Single Item",
                    description: "Add one piece at a time",
                    action: { showSingle = true }
                )

                ImportOptionCard(
                    icon: "magnifyingglass",
                    title: "Search Online",
                    description: "Find an item by brand/name and import the product image",
                    action: { showOnline = true }
                )

                Spacer()
            }
            .padding()
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

struct AddItemSingleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var capturedImage: UIImage?
    @State private var showCamera = true
    @State private var isProcessing = false
    @State private var tagResult: GeminiTagResult?
    @State private var errorMessage: String?

    // Editable fields
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
                        Text("Take a photo of the item")
                            .font(.headline)
                            .padding()
                        ImagePicker(image: $capturedImage, sourceType: .camera)
                    }
                    .onChange(of: capturedImage) { _, newValue in
                        if newValue != nil {
                            showCamera = false
                            processImage()
                        }
                    }
                } else if isProcessing {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Analyzing your item...")
                            .font(.headline)
                    }
                } else {
                    reviewForm
                }
            }
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
            VStack(spacing: 16) {
                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.horizontal)
                }

                VStack(spacing: 12) {
                    Picker("Category", selection: $category) {
                        ForEach(Category.allCases) { cat in
                            Text(cat.displayName).tag(cat)
                        }
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
                        ForEach(Pattern.allCases, id: \.self) { p in
                            Text(p.rawValue.capitalized).tag(p)
                        }
                    }

                    Picker("Material", selection: $material) {
                        ForEach(Material.allCases, id: \.self) { m in
                            Text(m.rawValue.capitalized).tag(m)
                        }
                    }

                    Picker("Formality", selection: $formality) {
                        ForEach(Formality.allCases, id: \.self) { f in
                            Text(f.displayName).tag(f)
                        }
                    }
                }
                .padding(.horizontal)

                Button(action: saveItem) {
                    Text("Add to Closet")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
    }

    private func processImage() {
        guard let image = capturedImage else { return }
        isProcessing = true

        Task {
            // Remove background
            let cleanImage = await ImageService.shared.removeBackground(from: image)
            await MainActor.run { capturedImage = cleanImage }

            // Auto-tag with Gemini
            do {
                let result = try await GeminiVisionService().tagSingleItem(image: cleanImage)
                await MainActor.run {
                    tagResult = result
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
                    errorMessage = "Auto-tagging unavailable, please tag manually."
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
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dismiss()
    }
}

struct AddItemBatchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var capturedImage: UIImage?
    @State private var showCamera = true
    @State private var isProcessing = false
    @State private var detectedItems: [DetectedBatchItem] = []
    @State private var errorMessage: String?

    struct DetectedBatchItem: Identifiable {
        let id = UUID()
        var image: UIImage
        var category: Category
        var primaryColor: String
        var pattern: Pattern
        var material: Material
        var formality: Formality
        var isSelected: Bool = true
    }

    var body: some View {
        NavigationStack {
            Group {
                if showCamera {
                    VStack {
                        Text("Lay your clothes flat and photograph the whole pile")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding()
                        ImagePicker(image: $capturedImage, sourceType: .camera)
                    }
                    .onChange(of: capturedImage) { _, newValue in
                        if newValue != nil {
                            showCamera = false
                            processBatch()
                        }
                    }
                } else if isProcessing {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Finding your clothes...")
                            .font(.headline)
                    }
                } else {
                    reviewList
                }
            }
            .navigationTitle("Batch Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var reviewList: some View {
        VStack {
            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.orange)
                    .padding()
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach($detectedItems) { $item in
                        VStack(spacing: 4) {
                            Image(uiImage: item.image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        item.isSelected.toggle()
                                    } label: {
                                        Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(item.isSelected ? .green : .gray)
                                            .font(.title3)
                                    }
                                    .padding(4)
                                }

                            Text(item.category.displayName)
                                .font(.caption)
                            Text(item.primaryColor)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }

            let selectedCount = detectedItems.filter(\.isSelected).count
            Button(action: saveItems) {
                Text("Add \(selectedCount) items to Closet")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedCount > 0 ? Color.accentColor : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(selectedCount == 0)
            .padding()
        }
    }

    private func processBatch() {
        guard let image = capturedImage else { return }
        isProcessing = true

        Task {
            do {
                let items = try await GeminiVisionService().detectBatchItems(image: image)

                var detected: [DetectedBatchItem] = []
                for batchItem in items {
                    // Crop the image using bounding box
                    let cropRect = CGRect(
                        x: batchItem.boundingBox.x * Double(image.size.width),
                        y: batchItem.boundingBox.y * Double(image.size.height),
                        width: batchItem.boundingBox.width * Double(image.size.width),
                        height: batchItem.boundingBox.height * Double(image.size.height)
                    )

                    if let cgImage = image.cgImage?.cropping(to: cropRect) {
                        var croppedImage = UIImage(cgImage: cgImage)
                        croppedImage = await ImageService.shared.removeBackground(from: croppedImage)

                        detected.append(DetectedBatchItem(
                            image: croppedImage,
                            category: Category(rawValue: batchItem.category) ?? .top,
                            primaryColor: batchItem.primaryColor,
                            pattern: Pattern(rawValue: batchItem.pattern) ?? .solid,
                            material: Material(rawValue: batchItem.materialEstimate) ?? .unknown,
                            formality: Formality(rawValue: batchItem.formality) ?? .casual
                        ))
                    }
                }

                await MainActor.run {
                    detectedItems = detected
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Could not detect items. Please try again or add items individually."
                    isProcessing = false
                }
            }
        }
    }

    private func saveItems() {
        for detected in detectedItems where detected.isSelected {
            let item = WardrobeItem(
                category: detected.category,
                subcategory: detected.category.rawValue,
                primaryColor: detected.primaryColor,
                pattern: detected.pattern,
                materialEstimate: detected.material,
                formality: detected.formality
            )

            try? ImageService.shared.saveItemPhoto(detected.image, fileName: item.photoFileName)
            modelContext.insert(item)
        }

        try? modelContext.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dismiss()
    }
}

struct OnlineSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchQuery = ""

    var body: some View {
        NavigationStack {
            VStack {
                Text("Search for clothing items by brand and name")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()

                Text("Coming soon — this feature requires a product image search API integration.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding()

                Spacer()
            }
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
