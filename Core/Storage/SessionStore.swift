import Foundation

final class SessionStore {
    static let shared = SessionStore()

    private let defaults: UserDefaults

    private enum Keys {
        static let userId = "tm_user_id"
        static let email = "tm_email"
        static let isPro = "tm_is_pro"
        static let planType = "tm_plan_type"
        static let isReviewer = "tm_is_reviewer"
        static let reviewerMode = "tm_reviewer_mode"
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Save

    func saveUser(_ user: TMUser) {
        defaults.set(user.id, forKey: Keys.userId)
        defaults.set(user.email, forKey: Keys.email)
        defaults.set(user.isPro, forKey: Keys.isPro)
        defaults.set(user.isReviewer, forKey: Keys.isReviewer)

        if let planType = user.planType, !planType.isEmpty {
            defaults.set(planType, forKey: Keys.planType)
        } else {
            defaults.removeObject(forKey: Keys.planType)
        }

        if let reviewerMode = user.reviewerMode, !reviewerMode.isEmpty {
            defaults.set(reviewerMode, forKey: Keys.reviewerMode)
        } else {
            defaults.removeObject(forKey: Keys.reviewerMode)
        }
    }

    // MARK: - Load

    func loadCachedUser() -> TMUser? {
        guard
            let id = defaults.string(forKey: Keys.userId),
            let email = defaults.string(forKey: Keys.email),
            !id.isEmpty,
            !email.isEmpty
        else {
            return nil
        }

        let isPro = defaults.bool(forKey: Keys.isPro)
        let planType = defaults.string(forKey: Keys.planType)
        let isReviewer = defaults.bool(forKey: Keys.isReviewer)
        let reviewerMode = defaults.string(forKey: Keys.reviewerMode)

        return TMUser(
            id: id,
            email: email,
            isPro: isPro,
            planType: planType,
            isReviewer: isReviewer,
            reviewerMode: reviewerMode
        )
    }

    // MARK: - Clear

    func clear() {
        defaults.removeObject(forKey: Keys.userId)
        defaults.removeObject(forKey: Keys.email)
        defaults.removeObject(forKey: Keys.isPro)
        defaults.removeObject(forKey: Keys.planType)
        defaults.removeObject(forKey: Keys.isReviewer)
        defaults.removeObject(forKey: Keys.reviewerMode)
    }

    // MARK: - Debug

    func debugDescription() -> String {
        """
        SessionStore:
        userId: \(defaults.string(forKey: Keys.userId) ?? "nil")
        email: \(defaults.string(forKey: Keys.email) ?? "nil")
        isPro: \(defaults.bool(forKey: Keys.isPro))
        planType: \(defaults.string(forKey: Keys.planType) ?? "nil")
        isReviewer: \(defaults.bool(forKey: Keys.isReviewer))
        reviewerMode: \(defaults.string(forKey: Keys.reviewerMode) ?? "nil")
        """
    }
}
