import SwiftUI

struct OnboardingFlow: View {
    @State private var currentStep = 0

    var body: some View {
        ZStack {
            MeshGradientBackground()

            Group {
                switch currentStep {
                case 0: WelcomeScreen { currentStep = 1 }
                case 1: AvatarSetupScreen { currentStep = 2 }
                case 2: ClosetImportScreen { currentStep = 3 }
                case 3: StyleBaselineScreen()
                default: WelcomeScreen { currentStep = 1 }
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: currentStep)
        }
    }
}

struct ProgressDots: View {
    let step: Int
    let totalSteps: Int

    var body: some View {
        VStack(spacing: DS.spacingSM) {
            HStack(spacing: DS.spacingSM) {
                ForEach(1...totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Color.accentColor : Color.primary.opacity(0.12))
                        .frame(width: i == step ? 28 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: step)
                }
            }

            Text("Step \(step) of \(totalSteps)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
