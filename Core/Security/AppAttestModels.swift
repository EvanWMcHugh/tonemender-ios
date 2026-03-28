import Foundation

struct AppAttestChallengeResponse: Codable {
    let challenge: String
    let challengeId: String?
    let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case challenge
        case challengeId = "challengeId"
        case expiresAt = "expiresAt"
    }
}

struct AppAttestAttestationRequest: Codable {
    let keyId: String
    let attestation: String
    let challenge: String
}

struct AppAttestSuccessResponse: Codable {
    let ok: Bool?
    let error: String?
}
