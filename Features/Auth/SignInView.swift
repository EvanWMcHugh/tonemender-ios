import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var showForgotPassword = false

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isFormValid: Bool {
        !normalizedEmail.isEmpty && !password.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                headerSection
                formSection

                Spacer()
            }
            .padding(24)
            .sheet(isPresented: $appViewModel.showSignUp) {
                SignUpView()
                    .environmentObject(appViewModel)
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView(prefilledEmail: email)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("ToneMender")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Sign in to continue")
                .foregroundStyle(.secondary)
        }
    }

    private var formSection: some View {
        VStack(spacing: 14) {
            emailField
            passwordField
            forgotPasswordButton

            errorSection
            verificationSection

            signInButton
            createAccountButton
        }
    }

    private var emailField: some View {
        TextField("Email", text: $email)
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
            .autocorrectionDisabled()
            .textContentType(.emailAddress)
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var passwordField: some View {
        SecureField("Password", text: $password)
            .textContentType(.password)
            .autocorrectionDisabled()
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var forgotPasswordButton: some View {
        HStack {
            Spacer()

            Button("Forgot password?") {
                showForgotPassword = true
            }
            .font(.footnote)
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = appViewModel.authError, !error.isEmpty {
            Text(error)
                .foregroundStyle(.red)
                .font(.footnote)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var verificationSection: some View {
        if appViewModel.needsEmailVerification {
            VStack(spacing: 10) {
                Text("Your account may still need email verification.")
                    .font(.footnote)
                    .fontWeight(.semibold)

                Text("Request a new verification email and try signing in again.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

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

                if let message = appViewModel.resendMessage, !message.isEmpty {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.green)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 8)
        }
    }

    private var signInButton: some View {
        Button {
            Task {
                await appViewModel.signIn(
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
                Text("Sign In")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(
            appViewModel.isLoading ||
            appViewModel.isResendingVerification ||
            !isFormValid
        )
    }

    private var createAccountButton: some View {
        Button("Create account") {
            appViewModel.showSignUp = true
        }
        .padding(.top, 4)
    }
}
