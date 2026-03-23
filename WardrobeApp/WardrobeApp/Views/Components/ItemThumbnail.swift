import SwiftUI

struct ItemThumbnail: View {
    let item: WardrobeItem
    var size: CGFloat? = nil
    var showConditionBadge: Bool = true

    var body: some View {
        Group {
            if let image = ImageCache.shared.load(from: item.photoURL) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(.systemGray5)
                    Image(systemName: categoryIcon)
                        .font(.title3)
                        .foregroundStyle(.quaternary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusSM))
        .overlay(alignment: .topTrailing) {
            if showConditionBadge && item.condition != .clean {
                Image(systemName: conditionIcon)
                    .font(.caption2)
                    .foregroundStyle(conditionColor)
                    .padding(3)
                    .background(Circle().fill(.ultraThinMaterial))
                    .padding(DS.spacingXS)
            }
        }
    }

    private var categoryIcon: String {
        switch item.category {
        case .top: return "tshirt"
        case .bottom: return "figure.walk"
        case .dress: return "figure.dress.line.vertical.figure"
        case .outerwear: return "cloud.snow"
        case .shoes: return "shoe"
        case .accessory: return "sparkles"
        }
    }

    private var conditionIcon: String {
        switch item.condition {
        case .needsCleaning: return "drop.triangle"
        case .needsTailoring: return "scissors"
        case .inStorage: return "archivebox"
        case .clean: return "checkmark"
        }
    }

    private var conditionColor: Color {
        switch item.condition {
        case .needsCleaning: return .orange
        case .needsTailoring: return .purple
        case .inStorage: return .blue
        case .clean: return .green
        }
    }
}

struct ItemCardView: View {
    let item: WardrobeItem

    var body: some View {
        VStack(spacing: DS.spacingXS) {
            ItemThumbnail(item: item)
                .aspectRatio(0.8, contentMode: .fit)

            Text(item.name ?? item.subcategory.capitalized)
                .font(.caption.weight(.medium))
                .lineLimit(1)

            Text(item.category.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct StatBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: DS.spacingXS) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
