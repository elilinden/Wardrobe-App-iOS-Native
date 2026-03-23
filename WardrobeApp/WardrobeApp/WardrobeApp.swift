import SwiftUI
import SwiftData

@main
struct WardrobeApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authService = AuthService()

    let modelContainer: ModelContainer

    init() {
        AppLog.data.info("WardrobeApp initializing...")

        // Initialize Keychain API key manager on launch
        _ = APIKeyManager.shared
        AppLog.data.info("API key manager initialized")

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
            AppLog.data.info("ModelContainer initialized successfully")
        } catch {
            AppLog.data.fault("Failed to initialize ModelContainer: \(error.localizedDescription)")
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
