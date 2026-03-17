import Foundation

struct AppAttestChallengeResponse: Codable {
    let challenge: String
}

struct AppAttestAttestationRequest: Codable {
    let keyId: String
    let attestation: String
    let challenge: String
}

struct AppAttestSuccessResponse: Codable {
    let ok: Bool
}
