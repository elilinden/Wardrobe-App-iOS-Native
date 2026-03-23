import SwiftUI
import SwiftData

@main
struct WardrobeApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authService = AuthService()

    let modelContainer: ModelContainer

    init() {
        // Initialize Keychain API key manager on launch
        _ = APIKeyManager.shared

        do {
            let schema = Schema([
                WardrobeItem.self,
                Outfit.self,
                PackingTrip.self,
                UserProfile.self,
                StylePreferences.self
            ])
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(authService)
                .modelContainer(modelContainer)
        }
    }
}
