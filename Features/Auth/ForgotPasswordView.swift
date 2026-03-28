import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    let prefilledEmail: String

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !normalizedEmail.isEmpty && !isLoading
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reset Password") {
                    Text("Enter your email and we’ll send you a password reset link.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if let errorMessage, !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if let successMessage, !successMessage.isEmpty {
                    Section {
                        Text(successMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        Task {
                            await submit()
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Send Reset Link")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
            .navigationTitle("Forgot Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if email.isEmpty {
                    email = prefilledEmail.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
    }

    private func submit() async {
        guard !normalizedEmail.isEmpty else {
            errorMessage = "Email is required."
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        defer { isLoading = false }

        do {
            let message = try await AuthService.shared.requestPasswordReset(email: normalizedEmail)
            successMessage = message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
