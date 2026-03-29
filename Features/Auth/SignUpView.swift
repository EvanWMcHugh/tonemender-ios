import SwiftUI

struct SignUpView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var email = ""
    @State private var password = ""

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
                    Button(appViewModel.signUpDidCreateAccount ? "Done" : "Close") {
                        appViewModel.resetSignUpFlow()
                        appViewModel.showSignUp = false
                    }
                }
            }
            .onAppear {
                appViewModel.needsEmailVerification = false
                appViewModel.authError = nil
                appViewModel.resendMessage = nil
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(appViewModel.signUpDidCreateAccount ? "Check your email" : "Create account")
                .font(.title2)
                .fontWeight(.bold)

            Text(
                appViewModel.signUpDidCreateAccount
                ? "Check your email to confirm your account."
                : "Start using ToneMender"
            )
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        VStack(spacing: 14) {
            if appViewModel.signUpDidCreateAccount {
                postSignUpSection
            } else {
                preSignUpSection
            }
        }
    }

    private var postSignUpSection: some View {
        VStack(spacing: 14) {
            Text("We sent a confirmation link to \(appViewModel.signUpEmail).")
                .font(.footnote)
                .multilineTextAlignment(.center)

            if let message = appViewModel.signUpMessage {
                Text(message)
                    .foregroundStyle(.secondary)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }

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
                    await appViewModel.resendVerification(email: appViewModel.signUpEmail)
                }
            } label: {
                if appViewModel.isResendingVerification {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                } else {
                    Text("Resend email verification")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
            }
            .buttonStyle(.bordered)
            .disabled(
                appViewModel.isLoading ||
                appViewModel.isResendingVerification ||
                appViewModel.signUpEmail.isEmpty
            )

            Button("Go to Sign In") {
                appViewModel.resetSignUpFlow()
                appViewModel.showSignUp = false
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

            Button {
                appViewModel.authError = nil
                appViewModel.resendMessage = nil

                Task {
                    _ = await appViewModel.signUp(
                        email: normalizedEmail,
                        password: password
                    )
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
