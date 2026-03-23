import SwiftUI

struct GlassChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            onTap()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            Text(title)
                .glassPill(isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct GlassChipSelector: View {
    let options: [String]
    let values: [String]
    @Binding var selected: String

    var body: some View {
        FlowLayout(spacing: DS.spacingSM) {
            ForEach(Array(zip(options, values)), id: \.1) { option, value in
                GlassChip(title: option, isSelected: selected == value) {
                    selected = value
                }
            }
        }
    }
}

struct GlassMultiChipSelector<T: Hashable>: View {
    let options: [(String, T)]
    @Binding var selected: Set<T>

    var body: some View {
        FlowLayout(spacing: DS.spacingSM) {
            ForEach(options, id: \.1) { title, value in
                GlassChip(title: title, isSelected: selected.contains(value)) {
                    if selected.contains(value) {
                        selected.remove(value)
                    } else {
                        selected.insert(value)
                    }
                }
            }
        }
    }
}

struct ColorExcludeChip: View {
    let colorName: String
    let isExcluded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            onTap()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            Text(colorName)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(isExcluded ? Color.red.opacity(0.15) : .ultraThinMaterial)
                }
                .overlay {
                    Capsule()
                        .strokeBorder(isExcluded ? Color.red.opacity(0.4) : Color.primary.opacity(0.08), lineWidth: 0.5)
                }
                .foregroundStyle(isExcluded ? .red : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct TagPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
