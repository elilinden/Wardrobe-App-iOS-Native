import SwiftUI

struct ClosetImportScreen: View {
    let onContinue: () -> Void
    @State private var showBatch = false
    @State private var showSingle = false
    @State private var showOnline = false

    var body: some View {
        VStack(spacing: DS.spacingXL) {
            ProgressDots(step: 2, totalSteps: 4)
                .padding(.top, DS.spacingLG)

            VStack(spacing: DS.spacingSM) {
                Text("Import Your Closet")
                    .font(.title.weight(.bold))

                Text("Choose how you'd like to add your clothes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

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
            }
            .padding(.horizontal, DS.spacingLG)

            Spacer()

            Button(action: {
                Haptic.light()
                onContinue()
            }) {
                Text("I'll do this later")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 50)
        }
        .sheet(isPresented: $showBatch) { AddItemBatchView() }
        .sheet(isPresented: $showSingle) { AddItemSingleView() }
        .sheet(isPresented: $showOnline) { OnlineSearchView() }
    }
}

struct ImportCard: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptic.light()
            action()
        }) {
            HStack(spacing: DS.spacingLG) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.accent)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: DS.spacingXS) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .glassCard(cornerRadius: DS.radiusLG)
        }
        .buttonStyle(.plain)
    }
}
