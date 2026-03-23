import SwiftUI

// MARK: - Design Constants

enum DS {
    // Spacing
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 24
    static let spacingXXL: CGFloat = 32

    // Corner Radius
    static let radiusSM: CGFloat = 8
    static let radiusMD: CGFloat = 12
    static let radiusLG: CGFloat = 16
    static let radiusXL: CGFloat = 24
    static let radiusPill: CGFloat = 100

    // Grid
    static let gridColumns3 = Array(repeating: GridItem(.flexible(), spacing: spacingMD), count: 3)
    static let gridColumns2 = Array(repeating: GridItem(.flexible(), spacing: spacingMD), count: 2)
    static let gridColumns4 = Array(repeating: GridItem(.flexible(), spacing: spacingSM), count: 4)

    // Limits
    static let monthlyRenderLimit = 30
    static let maxAccessories = 3
    static let defaultReWearGapDays = 14
    static let reWearGapRange: ClosedRange<Double> = 7...30
}

// MARK: - Glass Morphism Modifiers

struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = DS.radiusLG
    var opacity: Double = 0.6

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .opacity(opacity)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
    }
}

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = DS.radiusXL

    func body(content: Content) -> some View {
        content
            .padding(DS.spacingLG)
            .modifier(GlassBackground(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }
}

struct FloatingCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DS.spacingLG)
            .background {
                RoundedRectangle(cornerRadius: DS.radiusXL)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 16, y: 6)
            }
    }
}

struct GlassPill: ViewModifier {
    var isSelected: Bool = false

    func body(content: Content) -> some View {
        content
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.ultraThinMaterial))
            }
            .overlay {
                if !isSelected {
                    Capsule()
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                }
            }
            .foregroundStyle(isSelected ? .white : .primary)
    }
}

// MARK: - View Extensions

extension View {
    func glassBackground(cornerRadius: CGFloat = DS.radiusLG, opacity: Double = 0.6) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius, opacity: opacity))
    }

    func glassCard(cornerRadius: CGFloat = DS.radiusXL) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }

    func floatingCard() -> some View {
        modifier(FloatingCard())
    }

    func glassPill(isSelected: Bool = false) -> some View {
        modifier(GlassPill(isSelected: isSelected))
    }

    func settingsRow() -> some View {
        self
            .padding(.vertical, DS.spacingXS)
    }
}

// MARK: - Primary Button Style

struct GlassButtonStyle: ButtonStyle {
    var isProminent: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                if isProminent {
                    RoundedRectangle(cornerRadius: DS.radiusLG)
                        .fill(Color.accentColor)
                        .opacity(configuration.isPressed ? 0.8 : 1.0)
                } else {
                    RoundedRectangle(cornerRadius: DS.radiusLG)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: DS.radiusLG)
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                        }
                }
            }
            .foregroundStyle(isProminent ? .white : .primary)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: DS.radiusMD)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: DS.radiusMD)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                    }
            }
            .foregroundStyle(.primary)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Gradient Mesh Background

struct MeshGradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if colorScheme == .dark {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.06, blue: 0.14),
                    Color(red: 0.04, green: 0.08, blue: 0.12),
                    Color(red: 0.06, green: 0.04, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.93, blue: 0.98),
                    Color(red: 0.96, green: 0.95, blue: 0.99),
                    Color(red: 0.93, green: 0.95, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}
