import Foundation

enum RewriteTone: String, CaseIterable, Codable, Identifiable {
    case soft
    case calm
    case clear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .soft: return "Soft"
        case .calm: return "Calm"
        case .clear: return "Clear"
        }
    }
}

enum RewriteRecipient: String, CaseIterable, Codable, Identifiable {
    case partner
    case friend
    case family
    case coworker

    var id: String { rawValue }

    var title: String {
        switch self {
        case .partner: return "Partner"
        case .friend: return "Friend"
        case .family: return "Family"
        case .coworker: return "Coworker"
        }
    }
}

struct RewriteRequest: Codable {
    let message: String
    let recipient: RewriteRecipient
    let tone: RewriteTone
}

struct RewriteResponse: Codable {
    let soft: String
    let calm: String
    let clear: String
    let toneScore: Int
    let emotionPrediction: String
    let isPro: Bool
    let planType: String?
    let day: String
    let freeLimit: Int
    let rewritesToday: Int?

    enum CodingKeys: String, CodingKey {
        case soft
        case calm
        case clear
        case toneScore = "tone_score"
        case emotionPrediction = "emotion_prediction"
        case isPro = "is_pro"
        case planType = "plan_type"
        case day
        case freeLimit = "free_limit"
        case rewritesToday = "rewrites_today"
    }
}

