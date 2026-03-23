import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingFlow()
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appState.hasCompletedOnboarding)
    }
}

struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ClosetView()
                .tabItem {
                    Label("Closet", systemImage: "tshirt")
                }
                .tag(0)

            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.max")
                }
                .tag(1)

            BuilderView()
                .tabItem {
                    Label("Builder", systemImage: "square.stack.3d.up")
                }
                .tag(2)

            LookbookView()
                .tabItem {
                    Label("Lookbook", systemImage: "book.closed")
                }
                .tag(3)

            PackingView()
                .tabItem {
                    Label("Packing", systemImage: "suitcase")
                }
                .tag(4)
        }
        .tint(.accentColor)
    }
}
