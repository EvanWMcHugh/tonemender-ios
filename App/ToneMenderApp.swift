import SwiftUI

@main
struct ToneMenderApp: App {
    @StateObject private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environmentObject(appViewModel)
        }
    }
}
