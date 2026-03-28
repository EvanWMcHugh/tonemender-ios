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

        guard response.success == true, let draft = response.draft else {
            throw APIError.server(
                statusCode: 500,
                message: response.error ?? "Failed to save draft."
            )
        }

        return draft
    }

    func deleteDraft(draftId: String) async throws -> String {
        let normalizedDraftId = normalized(draftId)

        let request = DeleteDraftRequest(draftId: normalizedDraftId)

        let response = try await apiClient.post(
            "/api/messages/delete",
            body: request,
            as: DeleteDraftResponse.self
        )

        guard response.success == true, let deletedId = response.deletedId else {
            throw APIError.server(
                statusCode: 500,
                message: response.error ?? "Failed to delete draft."
            )
        }

        return deletedId
    }

    func deleteAllDrafts() async throws {
        let response = try await apiClient.post(
            "/api/messages/delete-all",
            as: DeleteAllDraftsResponse.self
        )

        guard response.success == true else {
            throw APIError.server(
                statusCode: 500,
                message: response.error ?? "Failed to delete drafts."
            )
        }
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
