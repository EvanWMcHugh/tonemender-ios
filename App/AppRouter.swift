import SwiftUI

struct AppRouter: View {
    @EnvironmentObject private var appViewModel: AppViewModel

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
            if appViewModel.currentUser == nil {
                await appViewModel.restoreSession()
            } else {
                appViewModel.isLoading = false
            }
        }
    }
}

