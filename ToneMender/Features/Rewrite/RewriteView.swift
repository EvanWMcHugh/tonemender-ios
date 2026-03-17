import SwiftUI
import UIKit

struct RewriteView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = RewriteViewModel()

    @State private var isSavingDraft = false
    @State private var draftSaveMessage: String? = nil

    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false

    private var isProUser: Bool {
        viewModel.isPro
    }

    private var rewritesToday: Int {
        viewModel.rewritesToday
    }

    private var freeLimit: Int {
        viewModel.freeLimit
    }

    private var remainingFreeRewrites: Int {
        viewModel.remainingFreeRewrites
    }

    private var freeLimitReached: Bool {
        viewModel.freeLimitReached
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection

                    if isProUser {
                        proBanner
                    } else {
                        freePlanBanner
                    }

                    inputSection

                    if isProUser {
                        recipientSection
                        toneSection
                    } else {
                        freeLockedSettingsSection
                    }

                    actionSection
                    feedbackSection
                    resultSection
                    statsSection
                }
                .padding(20)
            }
            .navigationTitle("Rewrite")
            .task {
                viewModel.configureCurrentUser(isPro: appViewModel.currentUser?.isPro == true)
                await viewModel.loadUsage()
            }
            .onChange(of: appViewModel.selectedDraftForRewrite?.id) { _ in
                if let draft = appViewModel.selectedDraftForRewrite {
                    viewModel.loadDraft(draft)
                    appViewModel.selectedDraftForRewrite = nil
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ActivityViewController(activityItems: shareItems)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ToneMender")
                .font(.largeTitle)
                .fontWeight(.bold)

            if let user = appViewModel.currentUser {
                Text(user.email)
                    .foregroundStyle(.secondary)

                Text(user.isPro ? "Pro" : "Free")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(user.isPro ? .blue : .secondary)
            }
        }
    }

    private var proBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ToneMender Pro")
                .font(.headline)
                .fontWeight(.semibold)

            Text("Unlimited rewrites with the full ToneMender experience.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var freePlanBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Free Plan")
                .font(.headline)
                .fontWeight(.semibold)

            if viewModel.isLoadingUsage {
                ProgressView()
            }

            Text("You have \(remainingFreeRewrites) of \(freeLimit) free rewrites left today.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if freeLimitReached {
                Text("You’ve used all free rewrites for today. Upgrade to Pro for unlimited rewrites.")
                    .font(.footnote)
                    .foregroundStyle(.blue)
            } else {
                Text("Upgrade to ToneMender Pro for unlimited rewrites, custom recipient selection, and preferred result controls.")
                    .font(.footnote)
                    .foregroundStyle(.blue)
            }

            NavigationLink {
                UpgradeView()
            } label: {
                Text("Upgrade to Pro")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Original message")
                .font(.headline)

            TextEditor(text: $viewModel.message)
                .frame(minHeight: 160)
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            HStack {
                Spacer()
                Text(viewModel.characterCountText)
                    .font(.footnote)
                    .foregroundStyle(viewModel.message.count > 2000 ? .red : .secondary)
            }

            if viewModel.result != nil && viewModel.hasEditedSinceLastRewrite {
                HStack {
                    Spacer()

                    Button("Revert to Original") {
                        viewModel.revertToOriginalMessage()
                        draftSaveMessage = nil
                    }
                    .font(.footnote)
                }
            }
        }
    }

    private var recipientSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recipient")
                .font(.headline)

            Picker("Recipient", selection: $viewModel.selectedRecipient) {
                ForEach(RewriteRecipient.allCases) { recipient in
                    Text(recipient.title).tag(recipient)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var toneSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preferred result")
                .font(.headline)

            Picker("Tone", selection: $viewModel.selectedTone) {
                ForEach(RewriteTone.allCases) { tone in
                    Text(tone.title).tag(tone)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var freeLockedSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rewrite settings")
                .font(.headline)

            Text("Upgrade to Pro to choose recipient and preferred result.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var actionSection: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    draftSaveMessage = nil
                    await viewModel.rewrite()
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    Text(freeLimitReached ? "Daily Limit Reached" : "Rewrite Message")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canRewrite)

            Button("Clear") {
                draftSaveMessage = nil
                viewModel.clearInputOnly()
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLoading && viewModel.result == nil)
        }
    }

    @ViewBuilder
    private var feedbackSection: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(.red)
                .multilineTextAlignment(.leading)
        } else if let copied = viewModel.copiedMessage {
            Text("\(copied) copied")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if let draftSaveMessage {
            Text(draftSaveMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        if let result = viewModel.result, let displayed = viewModel.displayedRewrite() {
            VStack(alignment: .leading, spacing: 16) {
                Text("Rewritten message")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 10) {
                    Text(viewModel.currentResultLabel)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    Text(displayed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    HStack {
                        Button("Copy") {
                            UIPasteboard.general.string = displayed
                            viewModel.markCopied(viewModel.currentResultLabel)
                            draftSaveMessage = nil
                        }
                        .buttonStyle(.bordered)

                        Button("Use This") {
                            viewModel.useRewrite(displayed)
                            draftSaveMessage = nil
                        }
                        .buttonStyle(.bordered)

                        Button(isSavingDraft ? "Saving..." : "Save Draft") {
                            Task {
                                await saveDraft()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSavingDraft)
                    }
                }

                beforeAfterSection(
                    before: viewModel.message.trimmingCharacters(in: .whitespacesAndNewlines),
                    after: displayed
                )

                shareSection(
                    before: viewModel.message.trimmingCharacters(in: .whitespacesAndNewlines),
                    after: displayed
                )

                if isProUser {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tone score")
                            .font(.headline)

                        Text("\(result.toneScore)/100")
                            .font(.title3)
                            .fontWeight(.bold)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Emotional impact")
                            .font(.headline)

                        Text(result.emotionPrediction)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Want more?")
                            .font(.headline)

                        Text("Upgrade to Pro to unlock custom recipient selection, preferred result controls, deeper analysis, and unlimited rewrites.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        NavigationLink {
                            UpgradeView()
                        } label: {
                            Text("See Pro")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private func beforeAfterSection(before: String, after: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Before & After")
                .font(.headline)

            BeforeAfterCardView(before: before, after: after)
        }
    }

    private func shareSection(before: String, after: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Share")
                .font(.headline)

            HStack {
                Button("Share Rewrite") {
                    shareRewrite(after: after)
                }
                .buttonStyle(.bordered)

                Button("Share Before / After") {
                    shareBeforeAfterCard(
                        before: before,
                        after: after,
                        toneLabel: viewModel.currentResultLabel
                    )
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Usage")
                .font(.headline)

            if isProUser {
                Text("Pro account • Unlimited rewrites")
                    .foregroundStyle(.secondary)
                Text("Total rewrites: \(viewModel.totalRewrites)")
                    .foregroundStyle(.secondary)
            } else {
                Text("Free rewrites today: \(rewritesToday)/\(freeLimit)")
                    .foregroundStyle(.secondary)
                Text("Total rewrites: \(viewModel.totalRewrites)")
                    .foregroundStyle(.secondary)

                if freeLimitReached {
                    Text("Upgrade to Pro for unlimited rewrites.")
                        .font(.footnote)
                        .foregroundStyle(.blue)
                }
            }
        }
    }

    private func saveDraft() async {
        let original = viewModel.message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else { return }

        guard let displayed = viewModel.displayedRewrite() else {
            draftSaveMessage = "Nothing to save yet"
            return
        }

        isSavingDraft = true
        draftSaveMessage = nil

        defer { isSavingDraft = false }

        do {
            switch viewModel.selectedTone {
            case .soft:
                _ = try await DraftService.shared.saveDraft(
                    original: original,
                    tone: "soft",
                    softRewrite: displayed,
                    calmRewrite: nil,
                    clearRewrite: nil
                )
            case .calm:
                _ = try await DraftService.shared.saveDraft(
                    original: original,
                    tone: "calm",
                    softRewrite: nil,
                    calmRewrite: displayed,
                    clearRewrite: nil
                )
            case .clear:
                _ = try await DraftService.shared.saveDraft(
                    original: original,
                    tone: "clear",
                    softRewrite: nil,
                    calmRewrite: nil,
                    clearRewrite: displayed
                )
            }

            draftSaveMessage = "Draft saved"
        } catch {
            draftSaveMessage = error.localizedDescription
        }
    }

    private func shareRewrite(after: String) {
        shareItems = [after]
        showShareSheet = true
    }

    private func shareBeforeAfterCard(before: String, after: String, toneLabel: String) {
        let card = BeforeAfterShareCardView(
            before: before,
            after: after,
            toneLabel: toneLabel,
            showWatermark: true
        )

        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale

        if let image = renderer.uiImage {
            shareItems = [image]
            showShareSheet = true
        } else {
            shareItems = [formattedBeforeAfterText(before: before, after: after)]
            showShareSheet = true
        }
    }

    private func formattedBeforeAfterText(before: String, after: String) -> String {
        """
        ToneMender Before / After

        Before:
        \(before)

        After:
        \(after)
        """
    }
}

private struct BeforeAfterCardView: View {
    let before: String
    let after: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardSection(
                title: "Before",
                text: before,
                background: Color(.systemGray6)
            )

            cardSection(
                title: "After",
                text: after,
                background: Color.blue.opacity(0.08)
            )
        }
    }

    private func cardSection(title: String, text: String, background: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

private struct BeforeAfterShareCardView: View {
    let before: String
    let after: String
    let toneLabel: String?
    let showWatermark: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            content
            footer
        }
        .padding(28)
        .frame(width: 1080)
        .background(
            LinearGradient(
                colors: [
                    Color.white,
                    Color.blue.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("ToneMender")
                    .font(.system(size: 42, weight: .bold))

                Text("Before / After")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let toneLabel, !toneLabel.isEmpty {
                Text(toneLabel)
                    .font(.system(size: 22, weight: .semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.12))
                    .foregroundStyle(Color.blue)
                    .clipShape(Capsule())
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            shareSection(
                title: "Before",
                text: before,
                background: Color(.systemGray6)
            )

            shareSection(
                title: "After",
                text: after,
                background: Color.blue.opacity(0.12)
            )
        }
    }

    private var footer: some View {
        HStack {
            Spacer()

            if showWatermark {
                Text("Made with ToneMender")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func shareSection(title: String, text: String, background: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 28, weight: .bold))

            Text(text)
                .font(.system(size: 26))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 24))
        }
    }
}

private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
