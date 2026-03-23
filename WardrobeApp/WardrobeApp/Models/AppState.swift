import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }
    @Published var selectedTab: Int = 0
    @Published var closetItemCount: Int = 0

    var showClosetNudgeBanner: Bool {
        hasCompletedOnboarding && closetItemCount < 5
    }

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }
}
