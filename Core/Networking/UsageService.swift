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

    private let apiClient = APIClient.shared

    private init() {}

    func fetchUsageStats() async throws -> UsageStats {
        let response = try await apiClient.get(
            "/api/usage/stats",
            as: UsageStatsResponse.self
        )
        return response.stats
    }
}
