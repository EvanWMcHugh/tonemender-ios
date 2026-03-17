import Foundation

struct BasicMessageResponse: Decodable {
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

    private let apiClient = APIClient.shared

    private init() {}

    func changeEmail(newEmail: String, currentPassword: String) async throws -> String {
        let body = ChangeEmailRequest(
            newEmail: newEmail,
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

        _ = try await apiClient.protectedPost(
            "/api/user/delete-account",
            body: body,
            as: BasicMessageResponse.self
        )
    }
}
