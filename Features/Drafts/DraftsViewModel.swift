import Foundation
import Combine

@MainActor
final class DraftsViewModel: ObservableObject {
    @Published var drafts: [Draft] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let draftService: DraftService

    init(draftService: DraftService) {
        self.draftService = draftService
    }

    convenience init() {
        self.init(draftService: .shared)
    }

    func loadDrafts() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            drafts = try await draftService.fetchDrafts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteDraft(_ draft: Draft) async {
        errorMessage = nil

        do {
            let deletedId = try await draftService.deleteDraft(draftId: draft.id)
            drafts.removeAll { $0.id == deletedId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteAllDrafts() async {
        errorMessage = nil

        do {
            try await draftService.deleteAllDrafts()
            drafts = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
