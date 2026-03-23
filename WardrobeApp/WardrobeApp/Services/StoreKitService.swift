import Foundation
import StoreKit

class StoreKitService: ObservableObject {
    @Published var hasUnlimitedRenders = false
    @Published var isLoading = false

    static let unlimitedRendersProductID = "com.wardrobeapp.unlimited_renders"

    init() {
        Task {
            await checkPurchaseStatus()
            await listenForTransactions()
        }
    }

    func checkPurchaseStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == Self.unlimitedRendersProductID {
                    await MainActor.run {
                        self.hasUnlimitedRenders = true
                    }
                }
            }
        }
    }

    func purchaseUnlimitedRenders() async throws {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        let products = try await Product.products(for: [Self.unlimitedRendersProductID])
        guard let product = products.first else {
            throw StoreError.productNotFound
        }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                await transaction.finish()
                await MainActor.run {
                    self.hasUnlimitedRenders = true
                }
            }
        case .userCancelled:
            break
        case .pending:
            break
        @unknown default:
            break
        }
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                if transaction.productID == Self.unlimitedRendersProductID {
                    await MainActor.run {
                        self.hasUnlimitedRenders = true
                    }
                }
                await transaction.finish()
            }
        }
    }
}

enum StoreError: LocalizedError {
    case productNotFound

    var errorDescription: String? {
        "Could not find the product. Please try again later."
    }
}
