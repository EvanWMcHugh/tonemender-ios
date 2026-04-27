import Foundation

struct PasswordResetRequest: Encodable {
    let email: String
}

struct ResendEmailVerificationRequest: Encodable {
    let email: String
}

struct BasicAuthMessageResponse: Decodable {
    let ok: Bool?
    let success: Bool?
    let message: String?
    let error: String?
}

@MainActor
final class AuthService {
    static let shared = AuthService()

    private let apiClient: APIClient

    private init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    private convenience init() {
        self.init(apiClient: APIClient.shared)
    }

    func restoreSession() async throws -> TMUser? {
        let response = try await apiClient.get(
            "/api/user/me",
            as: MeResponse.self
        )
        return response.user
    }

    func signIn(email: String, password: String) async throws -> TMUser {
        let normalizedEmail = normalizeEmail(email)

        let request = SignInRequest(
            email: normalizedEmail,
            password: password
        )

        let response = try await apiClient.post(
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
        let normalizedEmail = normalizeEmail(email)

        let request = SignUpRequest(
            email: normalizedEmail,
            password: password
        )

        return try await apiClient.protectedPost(
            "/api/auth/sign-up",
            body: request,
            as: AuthSuccessResponse.self
        )
    }

    func resendEmailVerification(email: String) async throws -> String {
        let request = ResendEmailVerificationRequest(
            email: normalizeEmail(email)
        )

        let response = try await apiClient.protectedPost(
            "/api/auth/resend-email-verification",
            body: request,
            as: BasicAuthMessageResponse.self
        )

        return response.message
            ?? "If that account exists and still needs verification, we sent a confirmation email."
    }

    func requestPasswordReset(email: String) async throws -> String {
        let request = PasswordResetRequest(
            email: normalizeEmail(email)
        )

        let response = try await apiClient.protectedPost(
            "/api/auth/request-password-reset",
            body: request,
            as: BasicAuthMessageResponse.self
        )

        return response.message
            ?? "If that email exists, a reset link has been sent."
    }

    func signOut() async {
        do {
            _ = try await apiClient.post(
                "/api/auth/sign-out",
                as: AuthSuccessResponse.self
            )
        } catch {
            // Best-effort sign-out. Local app state should still clear even if
            // the network request fails or the session has already expired.
        }
    }

    private func normalizeEmail(_ email: String) -> String {
        email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
