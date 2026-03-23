import SwiftUI

struct CalendarLookbookView: View {
    let outfits: [Outfit]
    let allItems: [WardrobeItem]

    @State private var selectedDate = Date()

    private var outfitsForDate: [Outfit] {
        let cal = Calendar.current
        let selected = cal.dateComponents([.year, .month, .day], from: selectedDate)
        return outfits.filter { outfit in
            let wornMatch = outfit.wornDates.contains {
                cal.dateComponents([.year, .month, .day], from: $0) == selected
            }
            let plannedMatch = outfit.plannedDate.map {
                cal.dateComponents([.year, .month, .day], from: $0) == selected
            } ?? false
            return wornMatch || plannedMatch
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.spacingLG) {
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(.accentColor)
                    .glassCard()
                    .padding(.horizontal, DS.spacingLG)

                if outfitsForDate.isEmpty {
                    Text("No outfits for this date")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    ForEach(outfitsForDate, id: \.id) { outfit in
                        OutfitCardView(outfit: outfit, allItems: allItems)
                            .padding(.horizontal, DS.spacingLG)
                    }
                }
            }
            .padding(.vertical, DS.spacingLG)
        }
    }
}
