import SwiftUI

struct AppRouter: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var didBootstrap = false

    var body: some View {
        Group {
            if appViewModel.isLoading {
                LoadingView()
            } else if appViewModel.isAuthenticated {
                MainTabView()
            } else {
                SignInView()
            }
        }
        .task {
            guard !didBootstrap else { return }
            didBootstrap = true
            await bootstrapSessionIfNeeded()
        }
    }

    private func bootstrapSessionIfNeeded() async {
        if appViewModel.currentUser == nil {
            await appViewModel.restoreSession()
        } else {
            appViewModel.isLoading = false
        }
    }
}
