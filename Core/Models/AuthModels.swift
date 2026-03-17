import Foundation

struct SignInRequest: Codable {
    let email: String
    let password: String
}

struct SignUpRequest: Codable {
    let email: String
    let password: String
}

struct AuthSuccessResponse: Codable {
    let ok: Bool?
    let success: Bool?
    let user: TMUser?
    let error: String?
    let message: String?
}
