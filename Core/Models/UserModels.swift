import Foundation

struct TMUser: Codable, Equatable {
    let id: String
    let email: String
    let isPro: Bool
    let planType: String?
    let isReviewer: Bool
    let reviewerMode: String?

    var effectivePlanType: String {
        planType ?? (isPro ? "pro" : "free")
    }
}

struct MeResponse: Codable {
    let user: TMUser?
}
