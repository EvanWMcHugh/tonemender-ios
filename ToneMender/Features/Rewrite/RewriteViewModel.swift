import Foundation
import Combine

@MainActor
final class RewriteViewModel: ObservableObject {
    @Published var message: String = "" {
        didSet {
            hasEditedSinceLastRewrite = normalized(message) != normalized(lastSubmittedMessage)
        }
    }

    @Published var selectedRecipient: RewriteRecipient = .partner
    @Published var selectedTone: RewriteTone = .soft

    @Published var result: RewriteResponse? = nil
    @Published var isLoading: Bool = false
    @Published var isLoadingUsage: Bool = false
    @Published var errorMessage: String? = nil
    @Published var copiedMessage: String? = nil

    @Published var rewritesToday: Int = 0
    @Published var totalRewrites: Int = 0
    @Published var freeLimit: Int = 3
    @Published var isPro: Bool = false

    @Published private(set) var lastSubmittedMessage: String = ""
    @Published private(set) var hasEditedSinceLastRewrite: Bool = false

    private let rewriteService = RewriteService.shared
    private let usageService = UsageService.shared

    var canRewrite: Bool {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 2000 && !isLoading && !freeLimitReached
    }

    var characterCountText: String {
        "\(message.count)/2000"
    }

    var remainingFreeRewrites: Int {
        max(0, freeLimit - rewritesToday)
    }

    var freeLimitReached: Bool {
        !isPro && remainingFreeRewrites == 0
    }

    var currentResultLabel: String {
        isPro ? selectedTone.title : "Default"
    }

    func configureCurrentUser(isPro: Bool) {
        self.isPro = isPro

        if !isPro {
            selectedRecipient = .partner
            selectedTone = .soft
        }
    }

    func loadUsage() async {
        isLoadingUsage = true
        defer { isLoadingUsage = false }

        do {
            let stats = try await usageService.fetchUsageStats()
            rewritesToday = stats.today
            totalRewrites = stats.total
        } catch {
            // silent on purpose so the rewrite screen still works
        }
    }

    func rewrite() async {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            errorMessage = "Message is required."
            return
        }

        guard trimmed.count <= 2000 else {
            errorMessage = "Message is too long."
            return
        }

        guard !freeLimitReached else {
            errorMessage = "You’ve used all free rewrites for today. Upgrade to Pro for unlimited rewrites."
            return
        }

        isLoading = true
        errorMessage = nil
        copiedMessage = nil

        defer { isLoading = false }

        do {
            let recipientToUse: RewriteRecipient = isPro ? selectedRecipient : .partner
            let toneToUse: RewriteTone = isPro ? selectedTone : .soft

            let response = try await rewriteService.rewrite(
                message: trimmed,
                recipient: recipientToUse,
                tone: toneToUse
            )

            result = response
            lastSubmittedMessage = trimmed
            hasEditedSinceLastRewrite = false

            isPro = response.isPro
            rewritesToday = response.rewritesToday ?? rewritesToday
            freeLimit = response.freeLimit

            if !isPro {
                selectedRecipient = .partner
                selectedTone = .soft
            }

            do {
                let stats = try await usageService.fetchUsageStats()
                rewritesToday = stats.today
                totalRewrites = stats.total
            } catch {
                totalRewrites += 1
            }
        } catch {
            result = nil
            errorMessage = error.localizedDescription
        }
    }

    func displayedRewrite() -> String? {
        guard let result else { return nil }

        switch selectedTone {
        case .soft:
            return nonEmpty(result.soft)
        case .calm:
            return nonEmpty(result.calm)
        case .clear:
            return nonEmpty(result.clear)
        }
    }

    func loadDraft(_ draft: Draft) {
        message = draft.original ?? ""
        errorMessage = nil
        copiedMessage = nil

        let savedTone = (draft.tone ?? "soft").lowercased()
        switch savedTone {
        case "calm":
            selectedTone = .calm
        case "clear":
            selectedTone = .clear
        default:
            selectedTone = .soft
        }

        if !isPro {
            selectedRecipient = .partner
            selectedTone = .soft
        }

        let originalText = draft.original ?? ""
        let softText = nonEmpty(draft.softRewrite) ?? originalText
        let calmText = nonEmpty(draft.calmRewrite) ?? originalText
        let clearText = nonEmpty(draft.clearRewrite) ?? originalText

        let currentDay = Self.currentPacificDayString()

        result = RewriteResponse(
            soft: softText,
            calm: calmText,
            clear: clearText,
            toneScore: 0,
            emotionPrediction: "Saved draft",
            isPro: isPro,
            planType: isPro ? "pro" : "free",
            day: currentDay,
            freeLimit: freeLimit,
            rewritesToday: rewritesToday
        )

        lastSubmittedMessage = originalText
        hasEditedSinceLastRewrite = false
    }

    func clearInputOnly() {
        message = ""
        errorMessage = nil
        copiedMessage = nil
    }

    func revertToOriginalMessage() {
        message = lastSubmittedMessage
        errorMessage = nil
        copiedMessage = nil
        hasEditedSinceLastRewrite = false
    }

    func useRewrite(_ text: String) {
        message = text
        errorMessage = nil
        copiedMessage = nil
    }

    func clearAll() {
        message = ""
        result = nil
        errorMessage = nil
        copiedMessage = nil
        selectedRecipient = .partner
        selectedTone = .soft
        lastSubmittedMessage = ""
        hasEditedSinceLastRewrite = false
    }

    func markCopied(_ label: String) {
        copiedMessage = label
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : value
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func currentPacificDayString() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
