import SwiftUI

struct SignUpView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var resultMessage: String?
    @State private var didCreateAccount = false

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !normalizedEmail.isEmpty && !password.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                headerSection
                contentSection
                Spacer()
            }
            .padding(24)
            .navigationTitle("Sign Up")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(didCreateAccount ? "Done" : "Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(didCreateAccount ? "Check your email" : "Create account")
                .font(.title2)
                .fontWeight(.bold)

            Text(
                didCreateAccount
                    ? "Verify your email to activate your account"
                    : "Start using ToneMender"
            )
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        VStack(spacing: 14) {
            if didCreateAccount {
                postSignUpSection
            } else {
                preSignUpSection
            }
        }
    }

    private var postSignUpSection: some View {
        VStack(spacing: 14) {
            Text("We sent a confirmation link to \(normalizedEmail).")
                .font(.footnote)
                .multilineTextAlignment(.center)

            Text("If you don’t see it, check your spam or junk folder.")
                .foregroundStyle(.secondary)
                .font(.footnote)
                .multilineTextAlignment(.center)

            if let authError = appViewModel.authError, !authError.isEmpty {
                Text(authError)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }

            if let resendMessage = appViewModel.resendMessage, !resendMessage.isEmpty {
                Text(resendMessage)
                    .foregroundStyle(.green)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await appViewModel.resendVerification(email: normalizedEmail)
                }
            } label: {
                if appViewModel.isResendingVerification {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                } else {
                    Text("Resend verification email")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
            }
            .buttonStyle(.bordered)
            .disabled(
                appViewModel.isLoading ||
                appViewModel.isResendingVerification ||
                normalizedEmail.isEmpty
            )

            Button("Go to Sign In") {
                dismiss()
            }
            .padding(.top, 4)
        }
    }

    private var preSignUpSection: some View {
        VStack(spacing: 14) {
            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textContentType(.emailAddress)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            SecureField("Password", text: $password)
                .textContentType(.newPassword)
                .autocorrectionDisabled()
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            if let authError = appViewModel.authError, !authError.isEmpty {
                Text(authError)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }

            if let resultMessage, !resultMessage.isEmpty {
                Text(resultMessage)
                    .foregroundStyle(.secondary)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }

            Button {
                resultMessage = nil
                appViewModel.authError = nil
                appViewModel.resendMessage = nil

                Task {
                    let message = await appViewModel.signUp(
                        email: normalizedEmail,
                        password: password
                    )

                    resultMessage = message

                    if appViewModel.needsEmailVerification {
                        didCreateAccount = true
                    }
                }
            } label: {
                if appViewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                } else {
                    Text("Create Account")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                appViewModel.isLoading ||
                appViewModel.isResendingVerification ||
                !canSubmit
            )
        }
    }
}
