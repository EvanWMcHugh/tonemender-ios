import Foundation
import Combine

@MainActor
final class AppViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var isAuthenticated = false
    @Published var currentUser: TMUser?
    @Published var authError: String?
    @Published var selectedDraftForRewrite: Draft?
    @Published var selectedTab = 0
    @Published var needsEmailVerification = false
    @Published var resendMessage: String?
    @Published var isResendingVerification = false
    @Published var showSignUp = false
    @Published var signUpDidCreateAccount = false
    @Published var signUpEmail = ""
    @Published var signUpMessage: String?

    private let sessionStore: SessionStore
    private let authService: AuthService
    private let appAttestService: AppAttestService

    init(
        sessionStore: SessionStore,
        authService: AuthService,
        appAttestService: AppAttestService
    ) {
        self.sessionStore = sessionStore
        self.authService = authService
        self.appAttestService = appAttestService

        let cachedUser = sessionStore.loadCachedUser()
        currentUser = cachedUser
        isAuthenticated = cachedUser != nil
        isLoading = false
    }

    convenience init() {
        self.init(
            sessionStore: .shared,
            authService: .shared,
            appAttestService: .shared
        )
    }

    func openDraftInRewrite(_ draft: Draft) {
        selectedDraftForRewrite = draft
        selectedTab = 0
    }

    func clearSelectedDraft() {
        selectedDraftForRewrite = nil
    }

    func restoreSession() async {
        isLoading = true
        clearAuthUIState()

        defer { isLoading = false }

        do {

            let user = try await authService.restoreSession()

            guard let user else {
                applySignedOutState(clearDraftSelection: false)
                return
            }

            currentUser = user
            isAuthenticated = true
            sessionStore.saveUser(user)
        } catch {
            applySignedOutState(clearDraftSelection: false)
        }
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        clearAuthUIState()

        defer { isLoading = false }

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
            sessionStore.clear()

            if isEmailVerificationError(message) {
                needsEmailVerification = true
            }
        }
    }

    func resendVerification(email: String) async {
        let normalizedEmail = normalizeEmail(email)

        guard !normalizedEmail.isEmpty else {
            authError = "Enter your email first."
            return
        }

        isResendingVerification = true
        resendMessage = nil
        authError = nil

        defer { isResendingVerification = false }

        do {
            let message = try await authService.resendEmailVerification(email: normalizedEmail)
            resendMessage = message
        } catch {
            authError = error.localizedDescription
        }
    }

    func signUp(email: String, password: String) async -> Bool {
        isLoading = true
        authError = nil
        resendMessage = nil
        needsEmailVerification = false

        defer { isLoading = false }

        do {
            _ = try await authService.signUp(email: email, password: password)

            signUpEmail = normalizeEmail(email)
            signUpMessage = "Check your email to confirm your account. If you don’t see it, check your spam or junk folder, then tap Resend email verification."
            signUpDidCreateAccount = true

            return true
        } catch {
            authError = error.localizedDescription
            needsEmailVerification = false
            signUpDidCreateAccount = false
            return false
        }
    }
    
    func resetSignUpFlow() {
        signUpDidCreateAccount = false
        signUpEmail = ""
        signUpMessage = nil
    }
    
    func signOut() async {
        isLoading = true

        defer { isLoading = false }

        await authService.signOut()
        applySignedOutState(clearDraftSelection: true)
    }

    private func clearAuthUIState() {
        authError = nil
        needsEmailVerification = false
        resendMessage = nil
        isResendingVerification = false
    }

    private func applySignedOutState(clearDraftSelection: Bool) {
        currentUser = nil
        isAuthenticated = false
        clearAuthUIState()
        sessionStore.clear()

        if clearDraftSelection {
            selectedDraftForRewrite = nil
        }
    }

    private func isEmailVerificationError(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("not confirmed")
            || lowercased.contains("not verified")
            || lowercased.contains("verify your email")
            || lowercased.contains("email verification")
    }

    private func normalizeEmail(_ email: String) -> String {
        email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
