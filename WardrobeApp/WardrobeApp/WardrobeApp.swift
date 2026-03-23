import SwiftUI
import SwiftData

@main
struct WardrobeApp: App {
    @StateObject private var appState = AppState()

    let modelContainer: ModelContainer

    init() {
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
                .modelContainer(modelContainer)
        }
    }
}
