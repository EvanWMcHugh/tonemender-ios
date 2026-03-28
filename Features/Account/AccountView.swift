import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = AccountViewModel()

    @State private var showChangeEmailSheet = false
    @State private var showDeleteAccountSheet = false
    @State private var showDeleteConfirmAlert = false

    var body: some View {
        NavigationStack {
            List {
                accountSection
                usageSection
                feedbackSection
                actionsSection
            }
            .navigationTitle("Account")
            .task {
                await viewModel.loadUsage()
            }
            .sheet(isPresented: $showChangeEmailSheet) {
                changeEmailSheet
            }
            .sheet(isPresented: $showDeleteAccountSheet) {
                deleteAccountSheet
            }
        }
    }

    // MARK: - Sections

    private var accountSection: some View {
        Section("Account") {
            if let user = appViewModel.currentUser {
                row(label: "Email", value: user.email)
                row(label: "Plan", value: user.isPro ? "Pro" : "Free")

                if let planType = user.planType, !planType.isEmpty {
                    row(label: "Plan Type", value: planType.capitalized)
                }
            } else {
                Text("No account loaded")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var usageSection: some View {
        Section("Usage") {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else {
                row(label: "Rewrites today", value: "\(viewModel.rewritesToday)")
                row(label: "Total rewrites", value: "\(viewModel.totalRewrites)")
            }
        }
    }

    @ViewBuilder
    private var feedbackSection: some View {
        if let success = viewModel.successMessage, !success.isEmpty {
            Section {
                Text(success)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }

        if let error = viewModel.errorMessage, !error.isEmpty {
            Section {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var actionsSection: some View {
        Section("Actions") {
            Button("Change Email") {
                showChangeEmailSheet = true
            }

            Button("Delete Account", role: .destructive) {
                showDeleteAccountSheet = true
            }

            Button("Sign Out", role: .destructive) {
                Task {
                    await appViewModel.signOut()
                }
            }
        }
    }

    // MARK: - Sheets

    private var changeEmailSheet: some View {
        NavigationStack {
            Form {
                Section("New Email") {
                    TextField("New email", text: $viewModel.newEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Confirm Identity") {
                    SecureField("Current password", text: $viewModel.currentPasswordForEmailChange)
                }

                if let error = viewModel.errorMessage, !error.isEmpty {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if let success = viewModel.successMessage, !success.isEmpty {
                    Section {
                        Text(success)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Change Email")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        showChangeEmailSheet = false
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit") {
                        Task {
                            let success = await viewModel.submitEmailChange()
                            if success {
                                showChangeEmailSheet = false
                            }
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
    }

    private var deleteAccountSheet: some View {
        NavigationStack {
            Form {
                Section("Delete Account") {
                    Text("This permanently deletes your account and data.")
                        .foregroundStyle(.red)
                }

                Section("Confirm Identity") {
                    SecureField("Current password", text: $viewModel.currentPasswordForDelete)
                }

                if let error = viewModel.errorMessage, !error.isEmpty {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Delete Account")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        showDeleteAccountSheet = false
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Continue", role: .destructive) {
                        showDeleteConfirmAlert = true
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .alert("Delete account permanently?", isPresented: $showDeleteConfirmAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        do {
                            try await viewModel.deleteAccount()
                            showDeleteAccountSheet = false
                            await appViewModel.signOut()
                        } catch {
                            // handled in view model
                        }
                    }
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
