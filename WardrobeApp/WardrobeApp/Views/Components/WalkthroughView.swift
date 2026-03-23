import SwiftUI

struct WalkthroughStep {
    let icon: String
    let title: String
    let description: String
    let tabIndex: Int?
}

struct WalkthroughView: View {
    @Binding var isPresented: Bool
    var onFinish: (() -> Void)? = nil

    @State private var currentStep = 0

    private let steps: [WalkthroughStep] = [
        WalkthroughStep(
            icon: "tshirt.fill",
            title: "Your Closet",
            description: "Add clothes by taking photos — we'll auto-tag the color, category, material, and more. Use batch mode to photograph a whole pile at once.",
            tabIndex: 0
        ),
        WalkthroughStep(
            icon: "sun.max.fill",
            title: "Daily Suggestions",
            description: "Every day, we suggest 3 outfits based on your weather, calendar, and what you haven't worn recently. Thumbs down to never see that combo again.",
            tabIndex: 1
        ),
        WalkthroughStep(
            icon: "square.stack.3d.up.fill",
            title: "Outfit Builder",
            description: "Mix and match items yourself. Pick one top, one bottom, shoes, and accessories. Save combos you like to your Lookbook.",
            tabIndex: 2
        ),
        WalkthroughStep(
            icon: "person.fill",
            title: "Virtual Try-On",
            description: "See how an outfit looks on you before getting dressed. Tap 'Try On' on any suggestion or saved outfit. 30 free renders per month.",
            tabIndex: nil
        ),
        WalkthroughStep(
            icon: "book.closed.fill",
            title: "Your Lookbook",
            description: "All your saved outfits in one place. Pin outfits to calendar dates to plan ahead. Mark outfits as worn to track your style.",
            tabIndex: 3
        ),
        WalkthroughStep(
            icon: "suitcase.fill",
            title: "Smart Packing",
            description: "Planning a trip? Tell us where and what you'll do — we'll build an optimized packing list that maximizes outfit combinations.",
            tabIndex: 4
        )
    ]

    var body: some View {
        ZStack {
            MeshGradientBackground()

            VStack(spacing: DS.spacingXL) {
                // Skip
                HStack {
                    Spacer()
                    Button("Skip") {
                        finish()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DS.spacingLG)

                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 140, height: 140)

                    Image(systemName: steps[currentStep].icon)
                        .font(.system(size: 52))
                        .foregroundStyle(.accent)
                        .symbolRenderingMode(.hierarchical)
                }
                .id(currentStep)
                .transition(.scale.combined(with: .opacity))

                // Text
                VStack(spacing: DS.spacingMD) {
                    Text(steps[currentStep].title)
                        .font(.title.weight(.bold))
                        .id("title-\(currentStep)")

                    Text(steps[currentStep].description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.spacingXXL)
                        .id("desc-\(currentStep)")
                }

                Spacer()

                // Progress dots
                HStack(spacing: DS.spacingSM) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Circle()
                            .fill(i == currentStep ? Color.accentColor : Color.primary.opacity(0.15))
                            .frame(width: i == currentStep ? 10 : 6, height: i == currentStep ? 10 : 6)
                            .animation(.spring(response: 0.3), value: currentStep)
                    }
                }

                // Buttons
                HStack(spacing: DS.spacingMD) {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation { currentStep -= 1 }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }

                    Button(currentStep == steps.count - 1 ? "Get Started" : "Next") {
                        if currentStep < steps.count - 1 {
                            withAnimation(.spring(response: 0.4)) { currentStep += 1 }
                        } else {
                            finish()
                        }
                    }
                    .buttonStyle(GlassButtonStyle())
                }
                .padding(.horizontal, DS.spacingXL)
                .padding(.bottom, 50)
            }
        }
        .interactiveDismissDisabled()
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "hasSeenWalkthrough")
        isPresented = false
        onFinish?()
    }
}
