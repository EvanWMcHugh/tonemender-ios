import SwiftUI

struct UpgradeView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @ObservedObject private var billingManager = BillingManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroSection
                    featuresSection
                    plansSection
                    restoreSection
                    statusSection
                }
                .padding(20)
            }
            .navigationTitle("Upgrade")
            .task {
                if billingManager.monthlyPlan == nil && billingManager.yearlyPlan == nil {
                    await billingManager.loadProducts()
                } else {
                    await billingManager.refreshSubscriptionStatus()
                }
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ToneMender Pro")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Unlock unlimited rewrites and the full premium experience.")
                .foregroundStyle(.secondary)

            if let user = appViewModel.currentUser {
                Text(user.isPro ? "Current Plan: Pro" : "Current Plan: Free")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(user.isPro ? .blue : .secondary)

                if let planType = user.planType, !planType.isEmpty {
                    Text("Plan Type: \(planType.capitalized)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if billingManager.hasActiveSubscription {
                Text("Active App Store subscription detected.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What you get")
                .font(.headline)

            featureRow("Unlimited rewrites")
            featureRow("Premium experience across devices")
            featureRow("Fast access to every tone")
        }
    }

    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Choose a plan")
                .font(.headline)

            if billingManager.isLoadingProducts {
                ProgressView("Loading plans...")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 12) {
                    planCard(
                        title: "Monthly",
                        subtitle: "Flexible monthly access",
                        price: billingManager.monthlyPlan?.displayPrice ?? "$7.99",
                        planType: .monthly
                    )
                    .opacity(billingManager.monthlyPlan == nil ? 0.7 : 1)

                    planCard(
                        title: "Yearly",
                        subtitle: "Best value for long-term use",
                        price: billingManager.yearlyPlan?.displayPrice ?? "$49.99",
                        planType: .yearly,
                        badge: "Best Value"
                    )
                    .opacity(billingManager.yearlyPlan == nil ? 0.7 : 1)
                }
            }
        }
    }

    private var restoreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Already subscribed?")
                .font(.headline)

            Button("Restore Purchases") {
                Task {
                    let restored = await billingManager.restorePurchases()
                    if restored {
                        await appViewModel.restoreSession()
                    }
                }
            }
            .buttonStyle(.bordered)
            .disabled(billingManager.isPurchasing || billingManager.isLoadingProducts)
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if let errorMessage = billingManager.errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(.red)
        } else if let success = billingManager.purchaseSuccessMessage {
            Text(success)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func featureRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.blue)

            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func planCard(
        title: String,
        subtitle: String,
        price: String,
        planType: BillingPlanType,
        badge: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let badge {
                    Text(badge)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            Text(price)
                .font(.title3)
                .fontWeight(.bold)

            Button(billingManager.isPurchasing ? "Processing..." : "Choose \(title)") {
                Task {
                    let purchased = await billingManager.purchase(planType: planType)
                    if purchased {
                        await appViewModel.restoreSession()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                billingManager.isPurchasing ||
                billingManager.isLoadingProducts ||
                (planType == .monthly && billingManager.monthlyPlan == nil) ||
                (planType == .yearly && billingManager.yearlyPlan == nil)
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

