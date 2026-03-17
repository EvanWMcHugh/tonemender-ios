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
        isLoading = true

        do {
            let user = try await authService.signIn(email: email, password: password)
            currentUser = user
            isAuthenticated = true
            sessionStore.saveUser(user)
        } catch {
            authError = error.localizedDescription
            currentUser = nil
            isAuthenticated = false
        }

        isLoading = false
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
        sessionStore.clear()
        isLoading = false
    }
}
