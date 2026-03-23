import Foundation
import AuthenticationServices
import SwiftUI

struct UserAccount: Codable {
    let userID: String
    var email: String?
    var fullName: String?
    var signInDate: Date

    var displayName: String {
        fullName ?? email ?? "User"
    }

    var initials: String {
        guard let name = fullName else { return "U" }
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? "U"
        let last = parts.count > 1 ? parts.last?.prefix(1) ?? "" : ""
        return "\(first)\(last)".uppercased()
    }
}

@MainActor
class AuthService: ObservableObject {
    @Published var currentUser: UserAccount?
    @Published var isSignedIn: Bool = false

    private let keychainKey = "com.wardrobeapp.userAccount"

    init() {
        loadSavedUser()
    }

    // MARK: - Sign In with Apple

    func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }

            let userID = credential.user
            let email = credential.email
            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            let account = UserAccount(
                userID: userID,
                email: email ?? currentUser?.email,
                fullName: fullName.isEmpty ? currentUser?.fullName : fullName,
                signInDate: Date()
            )

            currentUser = account
            isSignedIn = true
            saveUser(account)
            Haptic.success()

        case .failure:
            Haptic.error()
        }
    }

    func signOut() {
        currentUser = nil
        isSignedIn = false
        deleteUser()
        Haptic.light()
    }

    // MARK: - Persistence (Keychain)

    private func saveUser(_ user: UserAccount) {
        guard let data = try? JSONEncoder().encode(user) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecAttrService as String: "WardrobeApp"
        ]
        SecItemDelete(query as CFDictionary)

        var saveQuery = query
        saveQuery[kSecValueData as String] = data
        saveQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(saveQuery as CFDictionary, nil)
    }

    private func loadSavedUser() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecAttrService as String: "WardrobeApp",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let user = try? JSONDecoder().decode(UserAccount.self, from: data) else {
            return
        }

        currentUser = user
        isSignedIn = true
    }

    private func deleteUser() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecAttrService as String: "WardrobeApp"
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Sign In with Apple Button

struct SignInWithAppleButton: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        SignInWithAppleButtonRepresentable(
            onRequest: { request in
                request.requestedScopes = [.fullName, .email]
            },
            onCompletion: { result in
                authService.handleSignInResult(result)
            }
        )
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusMD))
    }
}

private struct SignInWithAppleButtonRepresentable: UIViewRepresentable {
    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .whiteOutline)
        button.addTarget(context.coordinator, action: #selector(Coordinator.handleTap), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onRequest: onRequest, onCompletion: onCompletion)
    }

    class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        let onRequest: (ASAuthorizationAppleIDRequest) -> Void
        let onCompletion: (Result<ASAuthorization, Error>) -> Void

        init(onRequest: @escaping (ASAuthorizationAppleIDRequest) -> Void,
             onCompletion: @escaping (Result<ASAuthorization, Error>) -> Void) {
            self.onRequest = onRequest
            self.onCompletion = onCompletion
        }

        @objc func handleTap() {
            let request = ASAuthorizationAppleIDProvider().createRequest()
            onRequest(request)
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            onCompletion(.success(authorization))
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            onCompletion(.failure(error))
        }

        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows.first ?? UIWindow()
        }
    }
}
