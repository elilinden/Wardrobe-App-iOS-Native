import SwiftUI

struct TipsView: View {
    private let tips: [(icon: String, title: String, body: String)] = [
        ("camera.viewfinder", "Batch Photo Tips",
         "Lay clothes flat with space between them on a contrasting surface. Good lighting helps AI detect items better."),

        ("hand.thumbsdown", "Train Your Suggestions",
         "Tap thumbs down on outfit suggestions you don't like. The app learns and avoids similar combinations."),

        ("calendar.badge.plus", "Plan Ahead",
         "In Builder, tap the menu and 'Pin to Calendar' to plan outfits for upcoming events."),

        ("tshirt", "Keep Tags Updated",
         "Mark items as 'Needs Cleaning' or 'In Storage' so they don't appear in suggestions."),

        ("arrow.clockwise", "Track What You Wear",
         "Swipe right on any item in List view to mark it as worn. This helps cost-per-wear calculations."),

        ("suitcase", "Smart Packing",
         "Select activities for your trip to get targeted suggestions. The app optimizes for maximum outfit combinations with minimum items."),

        ("person.fill", "Better Try-On Results",
         "Retake avatar photos in good lighting with a plain background for more realistic renders."),

        ("sparkles", "Re-tag After Updates",
         "When AI improves, use 'Re-tag All Items' in Settings to get better auto-detection on existing items.")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: DS.spacingMD) {
                ForEach(tips, id: \.title) { tip in
                    HStack(alignment: .top, spacing: DS.spacingMD) {
                        Image(systemName: tip.icon)
                            .font(.title3)
                            .foregroundStyle(.accent)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: DS.spacingXS) {
                            Text(tip.title)
                                .font(.subheadline.weight(.semibold))
                            Text(tip.body)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .glassCard()
                }
            }
            .padding(DS.spacingLG)
        }
        .background { MeshGradientBackground() }
        .navigationTitle("Tips & Tricks")
        .navigationBarTitleDisplayMode(.inline)
    }
}
