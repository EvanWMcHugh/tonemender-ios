import Foundation

final class SessionStore {
    static let shared = SessionStore()

    private let userDefaults = UserDefaults.standard

    private enum Keys {
        static let cachedEmail = "tm_cached_email"
        static let cachedIsPro = "tm_cached_is_pro"
        static let cachedPlanType = "tm_cached_plan_type"
        static let cachedUserId = "tm_cached_user_id"
    }

    private init() {}

    func saveUser(_ user: TMUser) {
        userDefaults.set(user.id, forKey: Keys.cachedUserId)
        userDefaults.set(user.email, forKey: Keys.cachedEmail)
        userDefaults.set(user.isPro, forKey: Keys.cachedIsPro)
        userDefaults.set(user.planType, forKey: Keys.cachedPlanType)
    }

    func loadCachedUser() -> TMUser? {
        guard
            let id = userDefaults.string(forKey: Keys.cachedUserId),
            let email = userDefaults.string(forKey: Keys.cachedEmail)
        else {
            return nil
        }

        let isPro = userDefaults.bool(forKey: Keys.cachedIsPro)
        let planType = userDefaults.string(forKey: Keys.cachedPlanType)

        return TMUser(
            id: id,
            email: email,
            isPro: isPro,
            planType: planType
        )
    }

    func clear() {
        userDefaults.removeObject(forKey: Keys.cachedUserId)
        userDefaults.removeObject(forKey: Keys.cachedEmail)
        userDefaults.removeObject(forKey: Keys.cachedIsPro)
        userDefaults.removeObject(forKey: Keys.cachedPlanType)
    }
}
