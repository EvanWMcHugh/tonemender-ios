import Foundation

@MainActor
final class RewriteService {
    static let shared = RewriteService()

    private let apiClient = APIClient.shared

    private init() {}

    func rewrite(
        message: String,
        recipient: RewriteRecipient,
        tone: RewriteTone
    ) async throws -> RewriteResponse {
        let request = RewriteRequest(
            message: message.trimmingCharacters(in: .whitespacesAndNewlines),
            recipient: recipient,
            tone: tone
        )

        return try await apiClient.post(
            "/api/rewrite",
            body: request,
            as: RewriteResponse.self
        )
    }
}

