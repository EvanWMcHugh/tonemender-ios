import Foundation
import Combine

@MainActor
final class AccountViewModel: ObservableObject {
    @Published var rewritesToday = 0
    @Published var totalRewrites = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    @Published var newEmail = ""
    @Published var currentPasswordForEmailChange = ""
    @Published var currentPasswordForDelete = ""

    private let usageService: UsageService
    private let accountService: AccountService

    init(
        usageService: UsageService,
        accountService: AccountService
    ) {
        self.usageService = usageService
        self.accountService = accountService
    }

    convenience init() {
        self.init(
            usageService: .shared,
            accountService: .shared
        )
    }

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
        let normalizedEmail = normalizeEmail(newEmail)

        guard !normalizedEmail.isEmpty else {
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
                newEmail: normalizedEmail,
                currentPassword: currentPasswordForEmailChange
            )

            successMessage = message
            newEmail = ""
            currentPasswordForEmailChange = ""
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteAccount() async throws {
        guard !currentPasswordForDelete.isEmpty else {
            let error = NSError(
                domain: "ToneMenderAccount",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Current password is required."
                ]
            )
            errorMessage = error.localizedDescription
            throw error
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

    private func normalizeEmail(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
