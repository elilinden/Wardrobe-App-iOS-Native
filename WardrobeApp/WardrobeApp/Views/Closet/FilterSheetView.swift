import SwiftUI

struct FilterSheetView: View {
    @Binding var selectedCategories: Set<Category>
    @Binding var selectedColors: Set<String>
    @Binding var selectedSeasons: Set<Season>
    @Binding var selectedFormalities: Set<Formality>
    @Binding var selectedConditions: Set<ItemCondition>
    @Environment(\.dismiss) private var dismiss

    private let colorOptions = [
        "black", "white", "navy", "gray", "brown", "beige",
        "red", "pink", "orange", "yellow", "green", "blue", "purple"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.spacingXL) {
                    filterSection("Category") {
                        GlassMultiChipSelector(
                            options: Category.allCases.map { ($0.displayName, $0) },
                            selected: $selectedCategories
                        )
                    }

                    filterSection("Color") {
                        GlassMultiChipSelector(
                            options: colorOptions.map { ($0.capitalized, $0) },
                            selected: $selectedColors
                        )
                    }

                    filterSection("Season") {
                        GlassMultiChipSelector(
                            options: Season.allCases.map { ($0.displayName, $0) },
                            selected: $selectedSeasons
                        )
                    }

                    filterSection("Formality") {
                        GlassMultiChipSelector(
                            options: Formality.allCases.map { ($0.displayName, $0) },
                            selected: $selectedFormalities
                        )
                    }

                    filterSection("Condition") {
                        GlassMultiChipSelector(
                            options: ItemCondition.allCases.map { ($0.displayName, $0) },
                            selected: $selectedConditions
                        )
                    }
                }
                .padding(DS.spacingLG)
            }
            .background { MeshGradientBackground() }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear All") {
                        selectedCategories.removeAll()
                        selectedColors.removeAll()
                        selectedSeasons.removeAll()
                        selectedFormalities.removeAll()
                        selectedConditions.removeAll()
                        Haptic.light()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        Haptic.light()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func filterSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            Text(title)
                .font(.headline)
            content()
        }
    }
}
