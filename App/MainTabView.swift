import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        TabView(selection: $appViewModel.selectedTab) {

            RewriteView()
                .tabItem {
                    Label("Rewrite", systemImage: "text.bubble")
                }
                .tag(0)

            DraftsView()
                .tabItem {
                    Label("Drafts", systemImage: "doc.text")
                }
                .tag(1)

            UpgradeView()
                .tabItem {
                    Label("Upgrade", systemImage: "crown")
                }
                .tag(2)

            AccountView()
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }
                .tag(3)
        }
    }
}
