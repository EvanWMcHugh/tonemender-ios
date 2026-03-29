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
        Self.isoFormatter.date(from: createdAt)
            ?? Self.fallbackIsoFormatter.date(from: createdAt)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackIsoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

// MARK: - Responses

struct DraftListResponse: Codable {
    let drafts: [Draft]
}

struct SaveDraftResponse: Codable {
    let ok: Bool?
    let success: Bool?
    let draft: Draft?
    let error: String?
}

struct DeleteDraftResponse: Codable {
    let ok: Bool?
    let success: Bool?
    let deletedId: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case success
        case deletedId = "deletedId"
        case error
    }

    init(ok: Bool?, success: Bool?, deletedId: String?, error: String?) {
        self.ok = ok
        self.success = success
        self.deletedId = deletedId
        self.error = error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)

        let ok = try container.decodeIfPresent(Bool.self, forKey: DynamicCodingKeys("ok"))
        let success = try container.decodeIfPresent(Bool.self, forKey: DynamicCodingKeys("success"))
        let deletedId =
            try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("deletedId")) ??
            container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("deleted_id"))
        let error = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("error"))

        self.init(ok: ok, success: success, deletedId: deletedId, error: error)
    }
}

struct DeleteAllDraftsResponse: Codable {
    let ok: Bool?
    let success: Bool?
    let error: String?
}

// MARK: - Requests

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

struct DeleteDraftRequest: Codable {
    let draftId: String

    enum CodingKeys: String, CodingKey {
        case draftId = "draftId"
    }
}

// MARK: - Helpers

private struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(_ string: String) {
        self.stringValue = string
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
