import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Bindable var item: WardrobeItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var outfits: [Outfit]

    @State private var showDelete = false

    private var itemOutfits: [Outfit] {
        outfits.filter { $0.itemIDs.contains(item.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.spacingXL) {
                    // Hero photo
                    heroImage

                    // Tags
                    FlowLayout(spacing: DS.spacingSM) {
                        TagPill(text: item.category.displayName, color: .blue)
                        TagPill(text: item.subcategory.capitalized, color: .purple)
                        TagPill(text: item.primaryColor.capitalized, color: .green)
                        if let sec = item.secondaryColor {
                            TagPill(text: sec.capitalized, color: .green)
                        }
                        TagPill(text: item.pattern.displayName, color: .orange)
                        TagPill(text: item.materialEstimate.displayName, color: .brown)
                        TagPill(text: item.formality.displayName, color: .indigo)
                        ForEach(item.seasons, id: \.self) { s in
                            TagPill(text: s.displayName, color: .teal)
                        }
                    }
                    .padding(.horizontal, DS.spacingLG)

                    // Editable fields
                    VStack(spacing: DS.spacingMD) {
                        editRow("Name", value: Binding(
                            get: { item.name ?? "" },
                            set: { item.name = $0.isEmpty ? nil : $0 }
                        ))
                        editRow("Brand", value: Binding(
                            get: { item.brand ?? "" },
                            set: { item.brand = $0.isEmpty ? nil : $0 }
                        ))

                        HStack {
                            Text("Condition").foregroundStyle(.secondary)
                            Spacer()
                            Picker("", selection: $item.conditionRaw) {
                                ForEach(ItemCondition.allCases, id: \.rawValue) { c in
                                    Text(c.displayName).tag(c.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        editRow("Notes", value: Binding(
                            get: { item.notes ?? "" },
                            set: { item.notes = $0.isEmpty ? nil : $0 }
                        ))
                    }
                    .glassCard()
                    .padding(.horizontal, DS.spacingLG)

                    // Stats
                    HStack(spacing: 0) {
                        StatBadge(label: "Times Worn", value: "\(item.timesWorn)")
                        StatBadge(label: "Cost/Wear", value: item.costPerWearFormatted)
                        StatBadge(label: "Last Worn", value: item.lastWornFormatted)
                    }
                    .glassCard()
                    .padding(.horizontal, DS.spacingLG)

                    // Outfit history
                    if !itemOutfits.isEmpty {
                        outfitHistory
                    }

                    // Actions
                    actionButtons
                }
                .padding(.bottom, DS.spacingXXL)
            }
            .background { MeshGradientBackground() }
            .navigationTitle(item.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete this item?", isPresented: $showDelete) {
                Button("Delete", role: .destructive) {
                    item.cleanupPhoto()
                    modelContext.delete(item)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the item from your closet and all outfits.")
            }
        }
    }

    private var heroImage: some View {
        Group {
            if let image = ImageCache.shared.load(from: item.photoURL) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: DS.radiusXL))
                    .shadow(color: .black.opacity(0.1), radius: 20, y: 8)
            } else {
                RoundedRectangle(cornerRadius: DS.radiusXL)
                    .fill(.ultraThinMaterial)
                    .frame(height: 240)
                    .overlay {
                        Image(systemName: item.category.icon)
                            .font(.system(size: 50))
                            .foregroundStyle(.quaternary)
                    }
            }
        }
        .padding(.horizontal, DS.spacingLG)
    }

    private var outfitHistory: some View {
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            Text("Outfit History")
                .font(.headline)
                .padding(.horizontal, DS.spacingLG)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.spacingMD) {
                    ForEach(itemOutfits, id: \.id) { outfit in
                        VStack(spacing: DS.spacingXS) {
                            RoundedRectangle(cornerRadius: DS.radiusSM)
                                .fill(.ultraThinMaterial)
                                .frame(width: 72, height: 90)
                                .overlay {
                                    if let url = outfit.tryOnRenderURL,
                                       let img = ImageCache.shared.load(from: url) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .clipShape(RoundedRectangle(cornerRadius: DS.radiusSM))
                                    } else {
                                        Image(systemName: "square.stack.3d.up")
                                            .foregroundStyle(.quaternary)
                                    }
                                }
                            Text(outfit.displayName)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, DS.spacingLG)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: DS.spacingMD) {
            Button { item.markWornToday() } label: {
                Label("Mark Worn Today", systemImage: "checkmark.circle")
            }
            .buttonStyle(SecondaryButtonStyle())

            if item.isWishlist {
                Button { item.convertFromWishlist() } label: {
                    Label("I Bought It!", systemImage: "bag")
                }
                .buttonStyle(GlassButtonStyle())
            }

            Button(role: .destructive) { showDelete = true } label: {
                Label("Delete Item", systemImage: "trash")
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, DS.spacingLG)
    }

    private func editRow(_ label: String, value: Binding<String>) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            TextField(label, text: value)
                .multilineTextAlignment(.trailing)
        }
    }
}
