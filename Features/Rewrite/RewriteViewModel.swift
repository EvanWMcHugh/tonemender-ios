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

    @Published var result: RewriteResponse?
    @Published var isLoading = false
    @Published var isLoadingUsage = false
    @Published var errorMessage: String?
    @Published var copiedMessage: String?

    @Published var rewritesToday = 0
    @Published var totalRewrites = 0
    @Published var freeLimit = 3
    @Published var isPro = false

    @Published private(set) var lastSubmittedMessage: String = ""
    @Published private(set) var hasEditedSinceLastRewrite = false

    private let rewriteService: RewriteService
    private let usageService: UsageService

    init(
        rewriteService: RewriteService,
        usageService: UsageService
    ) {
        self.rewriteService = rewriteService
        self.usageService = usageService
    }

    convenience init() {
        self.init(
            rewriteService: .shared,
            usageService: .shared
        )
    }

    // MARK: - Computed

    var canRewrite: Bool {
        let trimmed = normalized(message)
        return !trimmed.isEmpty &&
               trimmed.count <= 2000 &&
               !isLoading &&
               !freeLimitReached
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

    // MARK: - Setup

    func configureCurrentUser(isPro: Bool) {
        self.isPro = isPro

        if !isPro {
            resetToFreeDefaults()
        }
    }

    // MARK: - Usage

    func loadUsage() async {
        isLoadingUsage = true
        defer { isLoadingUsage = false }

        do {
            let stats = try await usageService.fetchUsageStats()
            rewritesToday = stats.today
            totalRewrites = stats.total
        } catch {
            // intentionally silent
        }
    }

    // MARK: - Rewrite

    func rewrite() async {
        let trimmed = normalized(message)

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
            let recipient = isPro ? selectedRecipient : .partner
            let tone = isPro ? selectedTone : .soft

            let response = try await rewriteService.rewrite(
                message: trimmed,
                recipient: recipient,
                tone: tone
            )

            applyRewriteResponse(response, originalMessage: trimmed)

            // refresh usage (non-blocking fallback safe)
            await refreshUsageAfterRewrite()

        } catch {
            result = nil
            errorMessage = error.localizedDescription
        }
    }

    private func applyRewriteResponse(_ response: RewriteResponse, originalMessage: String) {
        result = response
        lastSubmittedMessage = originalMessage
        hasEditedSinceLastRewrite = false

        isPro = response.isPro
        rewritesToday = response.rewritesToday ?? rewritesToday
        freeLimit = response.freeLimit

        if !isPro {
            resetToFreeDefaults()
        }
    }

    private func refreshUsageAfterRewrite() async {
        do {
            let stats = try await usageService.fetchUsageStats()
            rewritesToday = stats.today
            totalRewrites = stats.total
        } catch {
            totalRewrites += 1 // safe fallback
        }
    }

    // MARK: - Display

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

    // MARK: - Drafts

    func loadDraft(_ draft: Draft) {
        let original = draft.original ?? ""

        message = original
        errorMessage = nil
        copiedMessage = nil

        if isPro {
            selectedTone = toneFromString(draft.tone)
        } else {
            resetToFreeDefaults()
        }

        let currentDay = Self.currentPacificDayString()

        result = RewriteResponse(
            soft: nonEmpty(draft.softRewrite) ?? original,
            calm: nonEmpty(draft.calmRewrite) ?? original,
            clear: nonEmpty(draft.clearRewrite) ?? original,
            toneScore: 0,
            emotionPrediction: "Saved draft",
            isPro: isPro,
            planType: isPro ? "pro" : "free",
            day: currentDay,
            freeLimit: freeLimit,
            rewritesToday: rewritesToday
        )

        lastSubmittedMessage = original
        hasEditedSinceLastRewrite = false
    }

    // MARK: - Actions

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
        resetToFreeDefaults()
        lastSubmittedMessage = ""
        hasEditedSinceLastRewrite = false
    }

    func markCopied(_ label: String) {
        copiedMessage = label
    }

    // MARK: - Helpers

    private func resetToFreeDefaults() {
        selectedRecipient = .partner
        selectedTone = .soft
    }

    private func toneFromString(_ tone: String?) -> RewriteTone {
        switch tone?.lowercased() {
        case "calm": return .calm
        case "clear": return .clear
        default: return .soft
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = normalized(value)
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
