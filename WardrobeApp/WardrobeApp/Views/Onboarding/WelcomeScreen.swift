import SwiftUI

struct WelcomeScreen: View {
    let onContinue: () -> Void

    @State private var animateIn = false

    var body: some View {
        VStack(spacing: DS.spacingXXL) {
            Spacer()

            VStack(spacing: DS.spacingXL) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 140, height: 140)
                        .scaleEffect(animateIn ? 1 : 0.5)
                        .opacity(animateIn ? 1 : 0)

                    Image(systemName: "tshirt.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.accent)
                        .symbolEffect(.pulse, options: .repeating)
                        .scaleEffect(animateIn ? 1 : 0.3)
                        .opacity(animateIn ? 1 : 0)
                }

                VStack(spacing: DS.spacingMD) {
                    Text("Your wardrobe,\norganized.\nOutfits, decided.")
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)

                    Text("Private. No subscriptions. No social feed.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 10)
                }
            }

            Spacer()

            Button(action: {
                Haptic.medium()
                onContinue()
            }) {
                Text("Get Started")
            }
            .buttonStyle(GlassButtonStyle())
            .padding(.horizontal, DS.spacingXL)
            .padding(.bottom, 50)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 30)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                animateIn = true
            }
        }
    }
}
