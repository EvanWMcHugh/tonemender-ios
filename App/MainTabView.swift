import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        TabView(selection: $appViewModel.selectedTab) {
            rewriteTab
            draftsTab
            upgradeTab
            accountTab
        }
    }

    private var rewriteTab: some View {
        RewriteView()
            .tabItem {
                Label("Rewrite", systemImage: "text.bubble")
            }
            .tag(0)
    }

    private var draftsTab: some View {
        DraftsView()
            .tabItem {
                Label("Drafts", systemImage: "doc.text")
            }
            .tag(1)
    }

    private var upgradeTab: some View {
        UpgradeView()
            .tabItem {
                Label("Upgrade", systemImage: "crown")
            }
            .tag(2)
    }

    private var accountTab: some View {
        AccountView()
            .tabItem {
                Label("Account", systemImage: "person.circle")
            }
            .tag(3)
    }
}
