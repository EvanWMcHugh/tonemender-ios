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

    var fallbackDisplayPrice: String {
        switch self {
        case .monthly: return "$7.99"
        case .yearly: return "$49.99"
        }
    }

    var subtitle: String {
        switch self {
        case .monthly: return "Billed monthly"
        case .yearly: return "Billed yearly"
        }
    }
}

struct BillingPlan: Identifiable, Equatable {
    let id: String
    let planType: BillingPlanType
    let productId: String
    let displayName: String
    let displayPrice: String
}
