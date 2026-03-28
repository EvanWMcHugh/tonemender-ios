import Foundation

struct TMUser: Codable, Equatable {
    let id: String
    let email: String
    let isPro: Bool
    let planType: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case isPro = "is_pro"
        case planType = "plan_type"
    }

    var effectivePlanType: String {
        planType ?? (isPro ? "pro" : "free")
    }
}

struct MeResponse: Codable {
    let user: TMUser?
}
