import SwiftUI

/// Generates the app icon programmatically using SwiftUI.
/// Export this as a 1024x1024 PNG for the App Store icon.
struct AppIconView: View {
    var size: CGFloat = 1024

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.28, green: 0.35, blue: 0.85),
                    Color(red: 0.45, green: 0.30, blue: 0.90),
                    Color(red: 0.35, green: 0.50, blue: 0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle mesh overlay
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.15), Color.clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: size * 0.8
                    )
                )
                .frame(width: size * 1.2, height: size * 1.2)
                .offset(x: -size * 0.2, y: -size * 0.2)

            // Hanger icon
            VStack(spacing: size * -0.02) {
                // Hanger hook
                Path { path in
                    let center = size * 0.5
                    let hookWidth = size * 0.06
                    path.move(to: CGPoint(x: center, y: size * 0.18))
                    path.addCurve(
                        to: CGPoint(x: center + hookWidth, y: size * 0.24),
                        control1: CGPoint(x: center + hookWidth * 1.5, y: size * 0.17),
                        control2: CGPoint(x: center + hookWidth * 1.5, y: size * 0.24)
                    )
                }
                .stroke(Color.white, style: StrokeStyle(lineWidth: size * 0.025, lineCap: .round))

                // Hanger body
                Image(systemName: "tshirt.fill")
                    .font(.system(size: size * 0.38))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: size * 0.02)
            }

            // Small sparkle accents
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.06))
                .foregroundStyle(.white.opacity(0.6))
                .offset(x: size * 0.25, y: -size * 0.22)

            Image(systemName: "sparkle")
                .font(.system(size: size * 0.04))
                .foregroundStyle(.white.opacity(0.4))
                .offset(x: -size * 0.28, y: size * 0.15)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
    }
}

/// Decorative illustrations for empty states and onboarding.
struct IllustrationView: View {
    enum Illustration {
        case emptyCloset
        case emptyLookbook
        case emptyToday
        case emptyPacking
        case addItem
        case tryOn
        case success
    }

    let type: Illustration
    var size: CGFloat = 160

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor.opacity(0.08))
                .frame(width: size, height: size)

            Circle()
                .fill(backgroundColor.opacity(0.05))
                .frame(width: size * 0.75, height: size * 0.75)

            VStack(spacing: size * 0.04) {
                Image(systemName: iconName)
                    .font(.system(size: size * 0.28))
                    .foregroundStyle(backgroundColor.opacity(0.6))
                    .symbolRenderingMode(.hierarchical)

                if let secondaryIcon {
                    Image(systemName: secondaryIcon)
                        .font(.system(size: size * 0.12))
                        .foregroundStyle(backgroundColor.opacity(0.35))
                        .offset(x: size * 0.12, y: -size * 0.08)
                }
            }
        }
        .frame(width: size, height: size)
    }

    private var iconName: String {
        switch type {
        case .emptyCloset: return "tshirt"
        case .emptyLookbook: return "book.closed"
        case .emptyToday: return "sun.max"
        case .emptyPacking: return "suitcase"
        case .addItem: return "camera.viewfinder"
        case .tryOn: return "person.fill"
        case .success: return "checkmark.circle"
        }
    }

    private var secondaryIcon: String? {
        switch type {
        case .emptyCloset: return "plus.circle"
        case .emptyLookbook: return "sparkles"
        case .emptyToday: return "cloud.sun"
        case .emptyPacking: return "airplane"
        case .addItem: return "wand.and.stars"
        case .tryOn: return "wand.and.stars"
        case .success: return nil
        }
    }

    private var backgroundColor: Color {
        switch type {
        case .emptyCloset: return .blue
        case .emptyLookbook: return .purple
        case .emptyToday: return .orange
        case .emptyPacking: return .teal
        case .addItem: return .blue
        case .tryOn: return .indigo
        case .success: return .green
        }
    }
}

#Preview("App Icon") {
    AppIconView(size: 300)
}

#Preview("Illustrations") {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            IllustrationView(type: .emptyCloset)
            IllustrationView(type: .emptyLookbook)
        }
        HStack(spacing: 20) {
            IllustrationView(type: .emptyToday)
            IllustrationView(type: .emptyPacking)
        }
    }
}
