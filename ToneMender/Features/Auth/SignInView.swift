import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    @State private var showForgotPassword = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                VStack(spacing: 8) {
                    Text("ToneMender")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Sign in to continue")
                        .foregroundStyle(.secondary)
                }

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
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    HStack {
                        Spacer()

                        Button("Forgot password?") {
                            showForgotPassword = true
                        }
                        .font(.footnote)
                    }

                    if let authError = appViewModel.authError {
                        Text(authError)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task {
                            await appViewModel.signIn(
                                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
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
                        email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        password.isEmpty
                    )

                    Button("Create account") {
                        showSignUp = true
                    }
                    .padding(.top, 4)
                }

                Spacer()
            }
            .padding(24)
            .sheet(isPresented: $showSignUp) {
                SignUpView()
                    .environmentObject(appViewModel)
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView(prefilledEmail: email)
            }
        }
    }
}
