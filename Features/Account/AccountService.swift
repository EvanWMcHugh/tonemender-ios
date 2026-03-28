import Foundation

struct BasicMessageResponse: Decodable {
    let ok: Bool?
    let message: String?
    let error: String?
}

struct ChangeEmailRequest: Encodable {
    let newEmail: String
    let currentPassword: String
}

struct DeleteAccountRequest: Encodable {
    let password: String
}

@MainActor
final class AccountService {
    static let shared = AccountService()

    private let apiClient: APIClient

    private init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    private convenience init() {
        self.init(apiClient: APIClient.shared)
    }

    func changeEmail(newEmail: String, currentPassword: String) async throws -> String {
        let body = ChangeEmailRequest(
            newEmail: normalize(newEmail),
            currentPassword: currentPassword
        )

        let response = try await apiClient.protectedPost(
            "/api/auth/request-email-change",
            body: body,
            as: BasicMessageResponse.self
        )

        return response.message ?? "Check your email to confirm the change."
    }

    func deleteAccount(password: String) async throws {
        let body = DeleteAccountRequest(password: password)

        let response = try await apiClient.protectedPost(
            "/api/user/delete-account",
            body: body,
            as: BasicMessageResponse.self
        )

        if response.ok == false {
            throw APIError.server(
                statusCode: 500,
                message: response.error ?? "Failed to delete account."
            )
        }
    }

    // MARK: - Helpers

    private func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
