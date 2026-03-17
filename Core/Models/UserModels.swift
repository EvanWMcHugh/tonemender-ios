import Foundation

struct TMUser: Codable, Equatable {
    let id: String
    let email: String
    let isPro: Bool
    let planType: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case isPro = "isPro"
        case planType = "planType"
    }
}

struct MeResponse: Codable {
    let user: TMUser?
}
