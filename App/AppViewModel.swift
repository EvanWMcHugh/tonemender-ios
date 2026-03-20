import Foundation
import Combine

@MainActor
final class AppViewModel: ObservableObject {
    @Published var isLoading: Bool = true
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: TMUser? = nil
    @Published var authError: String? = nil
    @Published var selectedDraftForRewrite: Draft? = nil
    @Published var selectedTab: Int = 0
    @Published var needsEmailVerification: Bool = false
    @Published var resendMessage: String? = nil
    @Published var isResendingVerification: Bool = false

    private let sessionStore = SessionStore.shared
    private let authService = AuthService.shared
    private let appAttestService = AppAttestService.shared

    init() {
        currentUser = sessionStore.loadCachedUser()
        isAuthenticated = currentUser != nil
    }

    func openDraftInRewrite(_ draft: Draft) {
        selectedDraftForRewrite = draft
        selectedTab = 0
    }

    func restoreSession() async {
        isLoading = true
        authError = nil

        do {
            if appAttestService.isSupported {
                try? await appAttestService.ensureAttestedIfNeeded()
            }

            let user = try await authService.restoreSession()

            if let user {
                currentUser = user
                isAuthenticated = true
                sessionStore.saveUser(user)
            } else {
                currentUser = nil
                isAuthenticated = false
                sessionStore.clear()
            }
        } catch {
            currentUser = nil
            isAuthenticated = false
            sessionStore.clear()
        }

        isLoading = false
    }

    func signIn(email: String, password: String) async {
        authError = nil
        needsEmailVerification = false
        resendMessage = nil
        isLoading = true

        do {
            let user = try await authService.signIn(email: email, password: password)
            currentUser = user
            isAuthenticated = true
            sessionStore.saveUser(user)
        } catch {
            let message = error.localizedDescription

            authError = message
            currentUser = nil
            isAuthenticated = false

            if message.lowercased().contains("not confirmed") ||
                message.lowercased().contains("not verified") {
                needsEmailVerification = true
            }
        }

        isLoading = false
    }

    func resendVerification(email: String) async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty else {
            authError = "Enter your email first."
            return
        }

        isResendingVerification = true
        resendMessage = nil
        authError = nil

        do {
            let message = try await authService.resendEmailVerification(email: trimmedEmail)
            resendMessage = message
        } catch {
            authError = error.localizedDescription
        }

        isResendingVerification = false
    }

    func signUp(email: String, password: String) async -> String? {
        authError = nil
        isLoading = true

        defer { isLoading = false }

        do {
            let response = try await authService.signUp(email: email, password: password)
            return response.message ?? "Check your email to verify your account."
        } catch {
            authError = error.localizedDescription
            return nil
        }
    }

    func signOut() async {
        isLoading = true
        await authService.signOut()
        currentUser = nil
        isAuthenticated = false
        authError = nil
        needsEmailVerification = false
        resendMessage = nil
        isResendingVerification = false
        sessionStore.clear()
        isLoading = false
    }
}
