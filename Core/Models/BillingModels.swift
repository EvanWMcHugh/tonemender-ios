import Foundation

enum BillingPlanType: String, Identifiable, CaseIterable {
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }

    var subtitle: String {
        switch self {
        case .monthly: return "Billed monthly"
        case .yearly: return "Billed yearly"
        }
    }

    var fallbackDisplayPrice: String {
        switch self {
        case .monthly: return "$7.99"
        case .yearly: return "$49.99"
        }
    }
}

struct BillingPlan: Identifiable, Equatable {
    let id: String
    let planType: BillingPlanType
    let productId: String
    let displayName: String
    let displayPrice: String

    var effectivePrice: String {
        displayPrice.isEmpty ? planType.fallbackDisplayPrice : displayPrice
    }
}
