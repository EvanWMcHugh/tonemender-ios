import Foundation
import StoreKit
import Combine

@MainActor
final class BillingManager: ObservableObject {
    static let shared = BillingManager()

    // Change these only if your final App Store Connect product IDs differ.
    static let monthlyProductId = "com.tonemender.pro.monthly"
    static let yearlyProductId = "com.tonemender.pro.yearly"

    @Published var isLoadingProducts = false
    @Published var isPurchasing = false
    @Published var monthlyPlan: BillingPlan?
    @Published var yearlyPlan: BillingPlan?
    @Published var errorMessage: String?
    @Published var purchaseSuccessMessage: String?
    @Published var hasActiveSubscription = false

    private var productsById: [String: Product] = [:]
    private var transactionListenerTask: Task<Void, Never>?

    private init() {
        transactionListenerTask = observeTransactionUpdates()
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    func loadProducts() async {
        isLoadingProducts = true
        errorMessage = nil
        purchaseSuccessMessage = nil

        defer { isLoadingProducts = false }

        do {
            let products = try await Product.products(for: [
                Self.monthlyProductId,
                Self.yearlyProductId
            ])

            productsById = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })

            if let monthlyProduct = productsById[Self.monthlyProductId] {
                monthlyPlan = BillingPlan(
                    id: monthlyProduct.id,
                    planType: .monthly,
                    productId: monthlyProduct.id,
                    displayName: monthlyProduct.displayName,
                    displayPrice: monthlyProduct.displayPrice
                )
            } else {
                monthlyPlan = nil
            }

            if let yearlyProduct = productsById[Self.yearlyProductId] {
                yearlyPlan = BillingPlan(
                    id: yearlyProduct.id,
                    planType: .yearly,
                    productId: yearlyProduct.id,
                    displayName: yearlyProduct.displayName,
                    displayPrice: yearlyProduct.displayPrice
                )
            } else {
                yearlyPlan = nil
            }

            if monthlyPlan == nil && yearlyPlan == nil {
                errorMessage = "No subscription products were found."
            }

            await refreshSubscriptionStatus()
        } catch {
            monthlyPlan = nil
            yearlyPlan = nil
            errorMessage = error.localizedDescription
        }
    }

    func purchase(planType: BillingPlanType) async -> Bool {
        guard !isPurchasing else { return false }

        isPurchasing = true
        errorMessage = nil
        purchaseSuccessMessage = nil

        defer { isPurchasing = false }

        let productId: String = {
            switch planType {
            case .monthly:
                return Self.monthlyProductId
            case .yearly:
                return Self.yearlyProductId
            }
        }()

        guard let product = productsById[productId] else {
            errorMessage = "Subscription product is not loaded."
            return false
        }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verificationResult):
                let signedTransaction = verificationResult.jwsRepresentation
                let transaction = try checkVerified(verificationResult)

                guard Self.isManagedProductId(transaction.productID) else {
                    errorMessage = "Unexpected subscription product."
                    return false
                }

                try await syncPurchaseToBackend(signedTransaction: signedTransaction)
                await transaction.finish()
                await refreshSubscriptionStatus()

                purchaseSuccessMessage = "Purchase successful."
                errorMessage = nil
                return true

            case .userCancelled:
                errorMessage = "Purchase cancelled."
                return false

            case .pending:
                errorMessage = "Purchase is pending."
                return false

            @unknown default:
                errorMessage = "Purchase failed."
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func restorePurchases() async -> Bool {
        errorMessage = nil
        purchaseSuccessMessage = nil

        do {
            try await AppStore.sync()
            try await syncCurrentEntitlementsToBackend()
            await refreshSubscriptionStatus()

            purchaseSuccessMessage = "Purchases restored."
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func refreshSubscriptionStatus() async {
        var active = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            guard Self.isManagedProductId(transaction.productID) else { continue }
            guard !isExpiredOrRevoked(transaction) else { continue }

            active = true
            break
        }

        hasActiveSubscription = active
    }

    private func syncCurrentEntitlementsToBackend() async throws {
        var sawManagedEntitlement = false

        for await result in Transaction.currentEntitlements {
            let signedTransaction = result.jwsRepresentation
            let transaction = try checkVerified(result)

            guard Self.isManagedProductId(transaction.productID) else { continue }
            guard !isExpiredOrRevoked(transaction) else { continue }

            sawManagedEntitlement = true
            try await syncPurchaseToBackend(signedTransaction: signedTransaction)
        }

        if !sawManagedEntitlement {
            hasActiveSubscription = false
        }
    }

    private func syncPurchaseToBackend(signedTransaction: String) async throws {
        struct SyncRequest: Codable {
            let signedTransaction: String
        }

        struct SyncResponse: Codable {
            let ok: Bool?
            let isPro: Bool?
            let planType: String?
            let error: String?

            enum CodingKeys: String, CodingKey {
                case ok
                case isPro = "is_pro"
                case planType = "plan_type"
                case error
            }
        }

        let response = try await APIClient.shared.post(
            "/api/ios/billing/sync",
            body: SyncRequest(signedTransaction: signedTransaction),
            as: SyncResponse.self
        )

        guard response.ok == true else {
            throw NSError(
                domain: "ToneMenderBilling",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: response.error ?? "Backend billing sync failed."
                ]
            )
        }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            guard let self else { return }

            for await update in Transaction.updates {
                do {
                    let signedTransaction = update.jwsRepresentation
                    let transaction = try self.checkVerified(update)

                    guard Self.isManagedProductId(transaction.productID) else {
                        await transaction.finish()
                        continue
                    }

                    try await self.syncPurchaseToBackend(signedTransaction: signedTransaction)
                    await transaction.finish()
                    await self.refreshSubscriptionStatus()

                    self.purchaseSuccessMessage = "Subscription updated."
                    self.errorMessage = nil
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private static func isManagedProductId(_ productId: String) -> Bool {
        productId == monthlyProductId || productId == yearlyProductId
    }

    private func isExpiredOrRevoked(_ transaction: Transaction) -> Bool {
        if transaction.revocationDate != nil {
            return true
        }

        if let expirationDate = transaction.expirationDate,
           expirationDate <= Date() {
            return true
        }

        return false
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw NSError(
                domain: "ToneMenderBilling",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Transaction verification failed."
                ]
            )
        case .verified(let safe):
            return safe
        }
    }
}

