import SwiftUI
import UIKit

struct DraftsView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = DraftsViewModel()

    @State private var showDeleteAllAlert = false
    @State private var showErrorAlert = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Drafts")
                .toolbar { toolbarContent }
                .task { await loadDrafts() }
                .refreshable { await loadDrafts() }
                .alert("Delete all drafts?", isPresented: $showDeleteAllAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete All", role: .destructive) {
                        Task { await deleteAllDrafts() }
                    }
                } message: {
                    Text("This cannot be undone.")
                }
                .alert("Error", isPresented: $showErrorAlert) {
                    Button("OK") {
                        viewModel.errorMessage = nil
                    }
                } message: {
                    Text(viewModel.errorMessage ?? "Something went wrong.")
                }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.drafts.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.drafts.isEmpty {
            emptyStateView
        } else {
            List {
                ForEach(viewModel.drafts) { draft in
                    DraftRow(
                        draft: draft,
                        onOpen: { appViewModel.openDraftInRewrite(draft) },
                        onCopy: { copyDraft(draft) },
                        onDelete: {
                            Task {
                                await viewModel.deleteDraft(draft)
                                handleErrorIfNeeded()
                            }
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
        }
    }

    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if !viewModel.drafts.isEmpty {
                Button("Delete All", role: .destructive) {
                    showDeleteAllAlert = true
                }
            }
        }
    }

    // MARK: - Actions

    private func loadDrafts() async {
        await viewModel.loadDrafts()
        handleErrorIfNeeded()
    }

    private func deleteAllDrafts() async {
        await viewModel.deleteAllDrafts()
        handleErrorIfNeeded()
    }

    private func handleErrorIfNeeded() {
        if viewModel.errorMessage != nil {
            showErrorAlert = true
        }
    }

    private func copyDraft(_ draft: Draft) {
        UIPasteboard.general.string = bestDraftText(from: draft)
    }

    // MARK: - Helpers

    private func bestDraftText(from draft: Draft) -> String {
        let tone = (draft.tone ?? "").lowercased()
        let original = draft.original ?? ""

        switch tone {
        case "soft":
            return nonEmptyString(draft.softRewrite, fallback: original)
        case "calm":
            return nonEmptyString(draft.calmRewrite, fallback: original)
        case "clear":
            return nonEmptyString(draft.clearRewrite, fallback: original)
        default:
            return nonEmptyOptional(draft.softRewrite)
                ?? nonEmptyOptional(draft.calmRewrite)
                ?? nonEmptyOptional(draft.clearRewrite)
                ?? original
        }
    }

    private func nonEmptyOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : value
    }

    private func nonEmptyString(_ value: String?, fallback: String) -> String {
        nonEmptyOptional(value) ?? fallback
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("No Drafts")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Saved drafts will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Row

private struct DraftRow: View {
    let draft: Draft
    let onOpen: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            topRow
            previewSection
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var topRow: some View {
        HStack(alignment: .top) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(draftTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if let tone = draft.tone, !tone.isEmpty {
                        Text(tone.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 8) {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var previewSection: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                Text(draftPreview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                Text("Tap to open in Rewrite")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var originalText: String {
        draft.original ?? ""
    }

    private var draftTitle: String {
        let trimmed = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Draft" : String(trimmed.prefix(40))
    }

    private var draftPreview: String {
        let tone = (draft.tone ?? "").lowercased()

        switch tone {
        case "soft":
            return nonEmptyString(draft.softRewrite, fallback: originalText)
        case "calm":
            return nonEmptyString(draft.calmRewrite, fallback: originalText)
        case "clear":
            return nonEmptyString(draft.clearRewrite, fallback: originalText)
        default:
            return nonEmptyOptional(draft.softRewrite)
                ?? nonEmptyOptional(draft.calmRewrite)
                ?? nonEmptyOptional(draft.clearRewrite)
                ?? originalText
        }
    }

    private func nonEmptyOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : value
    }

    private func nonEmptyString(_ value: String?, fallback: String) -> String {
        nonEmptyOptional(value) ?? fallback
    }
}
