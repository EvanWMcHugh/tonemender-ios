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

                if let successMessage = viewModel.successMessage {
                    Section {
                        Text(successMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

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
            .navigationTitle("Account")
            .task {
                await viewModel.loadUsage()
            }
            .sheet(isPresented: $showChangeEmailSheet) {
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

                        if let errorMessage = viewModel.errorMessage {
                            Section {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }

                        if let successMessage = viewModel.successMessage {
                            Section {
                                Text(successMessage)
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
            .sheet(isPresented: $showDeleteAccountSheet) {
                NavigationStack {
                    Form {
                        Section("Delete Account") {
                            Text("This permanently deletes your account and data.")
                                .foregroundStyle(.red)
                        }

                        Section("Confirm Identity") {
                            SecureField("Current password", text: $viewModel.currentPasswordForDelete)
                        }

                        if let errorMessage = viewModel.errorMessage {
                            Section {
                                Text(errorMessage)
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
        }
    }

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
