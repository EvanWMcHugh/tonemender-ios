import Foundation

struct UsageStats: Decodable {
    let today: Int
    let total: Int
}

struct UsageStatsResponse: Decodable {
    let stats: UsageStats
}

@MainActor
final class UsageService {
    static let shared = UsageService()

    private let apiClient: APIClient

    private init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    private convenience init() {
        self.init(apiClient: APIClient.shared)
    }

    func fetchUsageStats() async throws -> UsageStats {
        let response = try await apiClient.get(
            "/api/usage/stats",
            as: UsageStatsResponse.self
        )
        return response.stats
    }
}
