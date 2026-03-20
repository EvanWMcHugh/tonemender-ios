import Foundation

struct PasswordResetRequest: Encodable {
    let email: String
}

struct BasicAuthMessageResponse: Decodable {
    let success: Bool?
    let message: String?
    let error: String?
}

@MainActor
final class AuthService {
    static let shared = AuthService()

    private let apiClient = APIClient.shared

    private init() {}

    func restoreSession() async throws -> TMUser? {
        let response = try await apiClient.get(
            "/api/user/me",
            as: MeResponse.self
        )
        return response.user
    }

    func signIn(email: String, password: String) async throws -> TMUser {
        let request = SignInRequest(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )

        let response = try await apiClient.protectedPost(
            "/api/auth/sign-in",
            body: request,
            as: AuthSuccessResponse.self
        )

        guard let user = response.user else {
            throw APIError.server(
                statusCode: 500,
                message: response.error ?? response.message ?? "Sign in failed."
            )
        }

        return user
    }

    func signUp(email: String, password: String) async throws -> AuthSuccessResponse {
        let request = SignUpRequest(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )

        return try await apiClient.protectedPost(
            "/api/auth/sign-up",
            body: request,
            as: AuthSuccessResponse.self
        )
    }

    func requestPasswordReset(email: String) async throws -> String {
        let request = PasswordResetRequest(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        let response = try await apiClient.protectedPost(
            "/api/auth/request-password-reset",
            body: request,
            as: BasicAuthMessageResponse.self
        )

        return response.message ?? "If that email exists, a reset link has been sent."
    }

    func signOut() async {
        _ = try? await apiClient.post(
            "/api/auth/sign-out",
            as: AuthSuccessResponse.self
        )
    }
}
