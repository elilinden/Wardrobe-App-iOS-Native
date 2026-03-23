import Foundation
import Security

/// Manages API keys securely using the iOS Keychain.
/// Keys should be set once during initial app configuration and are never stored in
/// the app bundle, UserDefaults, or any plaintext location.
///
/// Usage:
///   1. Set keys via Xcode scheme environment variables for development
///   2. For production, configure keys during app provisioning
///   3. Keys are stored in the Keychain and persist across app launches
final class APIKeyManager {
    static let shared = APIKeyManager()

    private enum KeyIdentifier: String {
        case gemini = "com.wardrobeapp.api.gemini"
        case pixelcut = "com.wardrobeapp.api.pixelcut"
    }

    private init() {
        // On first launch, migrate environment variable keys to Keychain
        migrateFromEnvironmentIfNeeded()
    }

    // MARK: - Public API

    var geminiAPIKey: String? {
        readKeychain(identifier: .gemini)
    }

    var pixelcutAPIKey: String? {
        readKeychain(identifier: .pixelcut)
    }

    var hasGeminiKey: Bool {
        geminiAPIKey?.isEmpty == false
    }

    var hasPixelcutKey: Bool {
        pixelcutAPIKey?.isEmpty == false
    }

    /// Store a key securely in the Keychain (e.g. from onboarding or settings)
    func setGeminiKey(_ key: String) {
        saveToKeychain(key: key, identifier: .gemini)
    }

    func setPixelcutKey(_ key: String) {
        saveToKeychain(key: key, identifier: .pixelcut)
    }

    func removeAllKeys() {
        deleteFromKeychain(identifier: .gemini)
        deleteFromKeychain(identifier: .pixelcut)
    }

    // MARK: - Keychain Operations

    private func saveToKeychain(key: String, identifier: KeyIdentifier) {
        guard let data = key.data(using: .utf8) else { return }

        // Delete existing entry first
        deleteFromKeychain(identifier: identifier)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier.rawValue,
            kSecAttrService as String: "WardrobeApp",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    private func readKeychain(identifier: KeyIdentifier) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier.rawValue,
            kSecAttrService as String: "WardrobeApp",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    private func deleteFromKeychain(identifier: KeyIdentifier) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier.rawValue,
            kSecAttrService as String: "WardrobeApp"
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Migration

    /// On first launch, check if API keys are in environment variables or Info.plist
    /// and move them to the Keychain for secure storage.
    private func migrateFromEnvironmentIfNeeded() {
        let migrated = UserDefaults.standard.bool(forKey: "apiKeysMigrated")
        guard !migrated else { return }

        // Check environment variables (dev) then Info.plist (build config)
        if let geminiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
            ?? Bundle.main.infoDictionary?["GeminiAPIKey"] as? String,
           !geminiKey.isEmpty, !geminiKey.starts(with: "$(") {
            setGeminiKey(geminiKey)
        }

        if let pixelcutKey = ProcessInfo.processInfo.environment["PIXELCUT_API_KEY"]
            ?? Bundle.main.infoDictionary?["PixelcutAPIKey"] as? String,
           !pixelcutKey.isEmpty, !pixelcutKey.starts(with: "$(") {
            setPixelcutKey(pixelcutKey)
        }

        UserDefaults.standard.set(true, forKey: "apiKeysMigrated")
    }
}
