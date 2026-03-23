import SwiftUI

struct FilterSheetView: View {
    @Binding var selectedCategories: Set<Category>
    @Binding var selectedColors: Set<String>
    @Binding var selectedSeasons: Set<Season>
    @Binding var selectedFormalities: Set<Formality>
    @Binding var selectedConditions: Set<ItemCondition>
    @Environment(\.dismiss) private var dismiss

    let colorOptions = ["black", "white", "navy", "gray", "brown", "beige",
                        "red", "pink", "orange", "yellow", "green", "blue", "purple"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Category
                    FilterSection(title: "Category") {
                        FlowLayout(spacing: 8) {
                            ForEach(Category.allCases) { cat in
                                FilterChip(
                                    title: cat.displayName,
                                    isSelected: selectedCategories.contains(cat),
                                    onTap: { toggleSet(&selectedCategories, cat) }
                                )
                            }
                        }
                    }

                    // Color
                    FilterSection(title: "Color") {
                        FlowLayout(spacing: 8) {
                            ForEach(colorOptions, id: \.self) { color in
                                FilterChip(
                                    title: color.capitalized,
                                    isSelected: selectedColors.contains(color),
                                    onTap: { toggleSet(&selectedColors, color) }
                                )
                            }
                        }
                    }

                    // Season
                    FilterSection(title: "Season") {
                        FlowLayout(spacing: 8) {
                            ForEach(Season.allCases, id: \.self) { season in
                                FilterChip(
                                    title: season.displayName,
                                    isSelected: selectedSeasons.contains(season),
                                    onTap: { toggleSet(&selectedSeasons, season) }
                                )
                            }
                        }
                    }

                    // Formality
                    FilterSection(title: "Formality") {
                        FlowLayout(spacing: 8) {
                            ForEach(Formality.allCases, id: \.self) { formality in
                                FilterChip(
                                    title: formality.displayName,
                                    isSelected: selectedFormalities.contains(formality),
                                    onTap: { toggleSet(&selectedFormalities, formality) }
                                )
                            }
                        }
                    }

                    // Condition
                    FilterSection(title: "Condition") {
                        FlowLayout(spacing: 8) {
                            ForEach(ItemCondition.allCases, id: \.self) { condition in
                                FilterChip(
                                    title: condition.displayName,
                                    isSelected: selectedConditions.contains(condition),
                                    onTap: { toggleSet(&selectedConditions, condition) }
                                )
                            }
                        }
                    }
                }
                .padding()
            }
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
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func toggleSet<T: Hashable>(_ set: inout Set<T>, _ value: T) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

struct FilterSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}
