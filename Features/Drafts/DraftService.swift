import Foundation

@MainActor
final class DraftService {
    static let shared = DraftService()

    private let apiClient: APIClient

    private init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    private convenience init() {
        self.init(apiClient: APIClient.shared)
    }

    func fetchDrafts() async throws -> [Draft] {
        let response = try await apiClient.get(
            "/api/messages",
            as: DraftListResponse.self
        )
        return response.drafts
    }

    func saveDraft(
        original: String,
        tone: String?,
        softRewrite: String?,
        calmRewrite: String?,
        clearRewrite: String?
    ) async throws -> Draft {
        let request = SaveDraftRequest(
            original: normalized(original),
            tone: normalizedOptional(tone),
            softRewrite: normalizedOptional(softRewrite),
            calmRewrite: normalizedOptional(calmRewrite),
            clearRewrite: normalizedOptional(clearRewrite)
        )

        let response = try await apiClient.post(
            "/api/messages",
            body: request,
            as: SaveDraftResponse.self
        )

        if let draft = response.draft {
            return draft
        }

        throw APIError.server(
            statusCode: 500,
            message: response.error ?? "Failed to save draft."
        )
    }

    func deleteDraft(draftId: String) async throws {
        let normalizedDraftId = normalized(draftId)

        let request = DeleteDraftRequest(draftId: normalizedDraftId)

        _ = try await apiClient.post(
            "/api/messages/delete",
            body: request,
            as: DeleteDraftResponse.self
        )
    }

    func deleteAllDrafts() async throws {
        _ = try await apiClient.post(
            "/api/messages/delete-all",
            as: DeleteAllDraftsResponse.self
        )
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = normalized(value)
        return trimmed.isEmpty ? nil : trimmed
    }
}
