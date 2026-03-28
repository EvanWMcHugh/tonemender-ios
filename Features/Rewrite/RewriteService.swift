import Foundation

@MainActor
final class RewriteService {
    static let shared = RewriteService()

    private let apiClient: APIClient

    private init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    private convenience init() {
        self.init(apiClient: APIClient.shared)
    }

    func rewrite(
        message: String,
        recipient: RewriteRecipient,
        tone: RewriteTone
    ) async throws -> RewriteResponse {
        let trimmedMessage = normalize(message)

        let request = RewriteRequest(
            message: trimmedMessage,
            recipient: recipient,
            tone: tone
        )

        return try await apiClient.post(
            "/api/rewrite",
            body: request,
            as: RewriteResponse.self
        )
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
