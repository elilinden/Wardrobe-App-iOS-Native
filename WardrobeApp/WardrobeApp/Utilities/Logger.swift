import Foundation
import os.log

/// Centralized logging for the Wardrobe app.
/// Uses Apple's unified logging system (os.log) for performance and privacy.
///
/// Usage:
///   AppLog.closet.info("Item added: \(item.displayName)")
///   AppLog.api.error("Gemini API failed: \(error)")
///   AppLog.auth.debug("Sign in completed for user: \(userID)")
enum AppLog {
    // MARK: - Log Categories

    /// Closet operations: adding, editing, deleting items
    static let closet = Logger(subsystem: subsystem, category: "Closet")

    /// Outfit operations: building, saving, wearing outfits
    static let outfit = Logger(subsystem: subsystem, category: "Outfit")

    /// Suggestion engine: generation, scoring, filtering
    static let suggestions = Logger(subsystem: subsystem, category: "Suggestions")

    /// API calls: Gemini Vision, Pixelcut Try-On
    static let api = Logger(subsystem: subsystem, category: "API")

    /// Weather and location services
    static let weather = Logger(subsystem: subsystem, category: "Weather")

    /// Calendar integration
    static let calendar = Logger(subsystem: subsystem, category: "Calendar")

    /// Image processing: background removal, caching, saving
    static let image = Logger(subsystem: subsystem, category: "Image")

    /// Authentication and user account
    static let auth = Logger(subsystem: subsystem, category: "Auth")

    /// In-app purchases and StoreKit
    static let store = Logger(subsystem: subsystem, category: "Store")

    /// Data persistence: SwiftData, CloudKit sync
    static let data = Logger(subsystem: subsystem, category: "Data")

    /// Navigation and UI state
    static let ui = Logger(subsystem: subsystem, category: "UI")

    /// Notifications
    static let notifications = Logger(subsystem: subsystem, category: "Notifications")

    /// Packing and trip planning
    static let packing = Logger(subsystem: subsystem, category: "Packing")

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.wardrobeapp.ios"
}
