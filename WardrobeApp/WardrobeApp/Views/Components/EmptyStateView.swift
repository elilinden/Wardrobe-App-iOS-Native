import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: DS.spacingLG) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 120, height: 120)

                Image(systemName: icon)
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: DS.spacingSM) {
                Text(title)
                    .font(.title3.weight(.semibold))

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.spacingXXL)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(GlassButtonStyle())
                .padding(.horizontal, 60)
            }

            Spacer()
        }
    }
}

struct GlassProgressView: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: DS.spacingLG) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(.accentColor)

            VStack(spacing: DS.spacingSM) {
                Text(title)
                    .font(.headline)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }
}
