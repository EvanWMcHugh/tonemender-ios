import Foundation

enum AppConfig {
    static let baseURL: URL = {
        guard let url = URL(string: "https://tonemender.com") else {
            fatalError("Invalid BASE_URL configuration")
        }
        return url
    }()
}
