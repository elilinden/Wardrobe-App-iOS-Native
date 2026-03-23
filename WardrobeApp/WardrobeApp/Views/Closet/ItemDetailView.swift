import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Bindable var item: WardrobeItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var outfits: [Outfit]

    @State private var showDeleteConfirmation = false

    private var itemOutfits: [Outfit] {
        outfits.filter { $0.itemIDs.contains(item.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Large photo
                    if let image = ImageService.shared.loadImage(from: item.photoURL) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 350)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray5))
                                .frame(height: 250)
                            Image(systemName: "tshirt")
                                .font(.system(size: 60))
                                .foregroundStyle(.quaternary)
                        }
                    }

                    // Tags
                    FlowLayout(spacing: 8) {
                        TagPill(text: item.category.displayName, color: .blue)
                        TagPill(text: item.subcategory.capitalized, color: .purple)
                        TagPill(text: item.primaryColor.capitalized, color: .green)
                        if let secondary = item.secondaryColor {
                            TagPill(text: secondary.capitalized, color: .green)
                        }
                        TagPill(text: item.pattern.rawValue.capitalized, color: .orange)
                        TagPill(text: item.materialEstimate.rawValue.capitalized, color: .brown)
                        TagPill(text: item.formality.displayName, color: .indigo)
                        ForEach(item.seasons, id: \.self) { season in
                            TagPill(text: season.displayName, color: .teal)
                        }
                    }
                    .padding(.horizontal)

                    // Editable fields
                    VStack(spacing: 12) {
                        EditableRow(label: "Name", value: Binding(
                            get: { item.name ?? "" },
                            set: { item.name = $0.isEmpty ? nil : $0 }
                        ))

                        EditableRow(label: "Brand", value: Binding(
                            get: { item.brand ?? "" },
                            set: { item.brand = $0.isEmpty ? nil : $0 }
                        ))

                        HStack {
                            Text("Condition")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Picker("", selection: $item.conditionRaw) {
                                ForEach(ItemCondition.allCases, id: \.rawValue) { condition in
                                    Text(condition.displayName).tag(condition.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        EditableRow(label: "Notes", value: Binding(
                            get: { item.notes ?? "" },
                            set: { item.notes = $0.isEmpty ? nil : $0 }
                        ))
                    }
                    .padding(.horizontal)

                    Divider()

                    // Stats
                    HStack(spacing: 24) {
                        StatItem(label: "Times Worn", value: "\(item.timesWorn)")
                        StatItem(
                            label: "Cost/Wear",
                            value: item.costPerWear.map { String(format: "$%.2f", $0) } ?? "—"
                        )
                        StatItem(
                            label: "Last Worn",
                            value: item.lastWorn.map {
                                let formatter = DateFormatter()
                                formatter.dateStyle = .short
                                return formatter.string(from: $0)
                            } ?? "Never"
                        )
                    }
                    .padding(.horizontal)

                    // Outfit history
                    if !itemOutfits.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Outfit History")
                                .font(.headline)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(itemOutfits, id: \.id) { outfit in
                                        VStack {
                                            if let renderURL = outfit.tryOnRenderURL,
                                               let image = ImageService.shared.loadImage(from: renderURL) {
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 80, height: 100)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                            } else {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color(.systemGray5))
                                                    .frame(width: 80, height: 100)
                                                    .overlay {
                                                        Image(systemName: "square.stack.3d.up")
                                                            .foregroundStyle(.quaternary)
                                                    }
                                            }
                                            Text(outfit.name ?? "Outfit")
                                                .font(.caption2)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Actions
                    VStack(spacing: 12) {
                        Button {
                            item.timesWorn += 1
                            item.lastWorn = Date()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Label("Mark Worn Today", systemImage: "checkmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        if item.isWishlist {
                            Button {
                                item.isWishlist = false
                                item.dateAdded = Date()
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            } label: {
                                Label("I Bought It!", systemImage: "bag")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Item", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(item.name ?? item.subcategory.capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete this item?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    modelContext.delete(item)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

struct EditableRow: View {
    let label: String
    @Binding var value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            TextField(label, text: $value)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TagPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
