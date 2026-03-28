import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()

            Text("Loading ToneMender...")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(.systemBackground))
    }
}
