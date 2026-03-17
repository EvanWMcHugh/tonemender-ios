import Foundation

struct Draft: Codable, Identifiable {
    let id: String
    let createdAt: String
    let original: String?
    let tone: String?
    let softRewrite: String?
    let calmRewrite: String?
    let clearRewrite: String?

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case original
        case tone
        case softRewrite = "soft_rewrite"
        case calmRewrite = "calm_rewrite"
        case clearRewrite = "clear_rewrite"
    }

    var createdAtDate: Date? {
        ISO8601DateFormatter().date(from: createdAt)
    }
}

struct DraftListResponse: Codable {
    let drafts: [Draft]
}

struct SaveDraftRequest: Codable {
    let original: String
    let tone: String?
    let softRewrite: String?
    let calmRewrite: String?
    let clearRewrite: String?

    enum CodingKeys: String, CodingKey {
        case original
        case tone
        case softRewrite = "soft_rewrite"
        case calmRewrite = "calm_rewrite"
        case clearRewrite = "clear_rewrite"
    }
}

struct SaveDraftResponse: Codable {
    let success: Bool?
    let draft: Draft?
    let error: String?
}

struct DeleteDraftRequest: Codable {
    let draftId: String
}

struct DeleteDraftResponse: Codable {
    let success: Bool?
    let deletedId: String?
    let error: String?
}

struct DeleteAllDraftsResponse: Codable {
    let success: Bool?
    let error: String?
}

