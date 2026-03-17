import SwiftUI
import UIKit

struct DraftsView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = DraftsViewModel()

    @State private var showDeleteAllAlert = false
    @State private var showErrorAlert = false

    var body: some View {
        NavigationStack {
            Group {
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
                                onOpen: {
                                    appViewModel.openDraftInRewrite(draft)
                                },
                                onCopy: {
                                    copyDraft(draft)
                                },
                                onDelete: {
                                    Task {
                                        await viewModel.deleteDraft(draft)
                                        if viewModel.errorMessage != nil {
                                            showErrorAlert = true
                                        }
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
            .navigationTitle("Drafts")
            .toolbar {
                if !viewModel.drafts.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Delete All", role: .destructive) {
                            showDeleteAllAlert = true
                        }
                    }
                }
            }
            .task {
                await viewModel.loadDrafts()
                if viewModel.errorMessage != nil {
                    showErrorAlert = true
                }
            }
            .refreshable {
                await viewModel.loadDrafts()
                if viewModel.errorMessage != nil {
                    showErrorAlert = true
                }
            }
            .alert("Delete all drafts?", isPresented: $showDeleteAllAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete All", role: .destructive) {
                    Task {
                        await viewModel.deleteAllDrafts()
                        if viewModel.errorMessage != nil {
                            showErrorAlert = true
                        }
                    }
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

    private func copyDraft(_ draft: Draft) {
        UIPasteboard.general.string = bestDraftText(from: draft)
    }

    private func bestDraftText(from draft: Draft) -> String {
        let tone = (draft.tone ?? "").lowercased()
        let original = draft.original ?? ""

        if tone == "soft" {
            return nonEmptyString(draft.softRewrite, fallback: original)
        } else if tone == "calm" {
            return nonEmptyString(draft.calmRewrite, fallback: original)
        } else if tone == "clear" {
            return nonEmptyString(draft.clearRewrite, fallback: original)
        } else {
            if let soft = nonEmptyOptional(draft.softRewrite) {
                return soft
            }
            if let calm = nonEmptyOptional(draft.calmRewrite) {
                return calm
            }
            if let clear = nonEmptyOptional(draft.clearRewrite) {
                return clear
            }
            return original
        }
    }

    private func nonEmptyOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : value
    }

    private func nonEmptyString(_ value: String?, fallback: String) -> String {
        if let value = nonEmptyOptional(value) {
            return value
        }
        return fallback
    }
}

private struct DraftRow: View {
    let draft: Draft
    let onOpen: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    Button {
                        onCopy()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(draftPreview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)

                    Text("Tap to open in Rewrite")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var originalText: String {
        draft.original ?? ""
    }

    private var draftTitle: String {
        let trimmed = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Untitled Draft"
        }
        return String(trimmed.prefix(40))
    }

    private var draftPreview: String {
        let tone = (draft.tone ?? "").lowercased()

        if tone == "soft" {
            return nonEmptyString(draft.softRewrite, fallback: originalText)
        } else if tone == "calm" {
            return nonEmptyString(draft.calmRewrite, fallback: originalText)
        } else if tone == "clear" {
            return nonEmptyString(draft.clearRewrite, fallback: originalText)
        } else {
            if let soft = nonEmptyOptional(draft.softRewrite) {
                return soft
            }
            if let calm = nonEmptyOptional(draft.calmRewrite) {
                return calm
            }
            if let clear = nonEmptyOptional(draft.clearRewrite) {
                return clear
            }
            return originalText
        }
    }

    private func nonEmptyOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : value
    }

    private func nonEmptyString(_ value: String?, fallback: String) -> String {
        if let value = nonEmptyOptional(value) {
            return value
        }
        return fallback
    }
}
