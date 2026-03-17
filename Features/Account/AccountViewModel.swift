import Foundation
import Combine

@MainActor
final class AccountViewModel: ObservableObject {
    @Published var rewritesToday: Int = 0
    @Published var totalRewrites: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil

    @Published var newEmail: String = ""
    @Published var currentPasswordForEmailChange: String = ""
    @Published var currentPasswordForDelete: String = ""

    private let usageService = UsageService.shared
    private let accountService = AccountService.shared

    func loadUsage() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let stats = try await usageService.fetchUsageStats()
            rewritesToday = stats.today
            totalRewrites = stats.total
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submitEmailChange() async -> Bool {
        let trimmedEmail = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty else {
            errorMessage = "New email is required."
            return false
        }

        guard !currentPasswordForEmailChange.isEmpty else {
            errorMessage = "Current password is required."
            return false
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        defer { isLoading = false }

        do {
            let message = try await accountService.changeEmail(
                newEmail: trimmedEmail,
                currentPassword: currentPasswordForEmailChange
            )
            successMessage = message
            currentPasswordForEmailChange = ""
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteAccount() async throws {
        guard !currentPasswordForDelete.isEmpty else {
            throw NSError(domain: "", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Current password is required."
            ])
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        defer { isLoading = false }

        do {
            try await accountService.deleteAccount(password: currentPasswordForDelete)
            currentPasswordForDelete = ""
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}
