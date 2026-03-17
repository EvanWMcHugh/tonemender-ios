import Foundation
import DeviceCheck
import CryptoKit

enum AppAttestError: LocalizedError {
    case notSupported
    case invalidChallenge
    case missingKeyId
    case invalidAttestationData
    case invalidAssertionData

    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "App Attest is not supported on this device."
        case .invalidChallenge:
            return "Invalid App Attest challenge."
        case .missingKeyId:
            return "Missing App Attest key."
        case .invalidAttestationData:
            return "Failed to create attestation data."
        case .invalidAssertionData:
            return "Failed to create assertion data."
        }
    }
}

@MainActor
final class AppAttestService {
    static let shared = AppAttestService()

    private let service = DCAppAttestService.shared
    private let apiClient = APIClient.shared

    private let keyIdDefaultsKey = "tm_app_attest_key_id"
    private let attestedDefaultsKey = "tm_app_attest_attested"

    private init() {}

    var isSupported: Bool {
        service.isSupported
    }

    // MARK: - Public API expected by APIClient

    func ensureKeyId() async throws -> String {
        guard service.isSupported else {
            throw AppAttestError.notSupported
        }

        return try await getOrCreateKeyId()
    }

    func ensureAttestedIfNeeded() async throws {
        guard service.isSupported else {
            throw AppAttestError.notSupported
        }

        let keyId = try await getOrCreateKeyId()

        if UserDefaults.standard.bool(forKey: attestedDefaultsKey) {
            return
        }

        let challengeResponse = try await apiClient.post(
            "/api/ios/app-attest/challenge",
            headers: [
                "x-client-platform": "ios"
            ],
            as: AppAttestChallengeResponse.self
        )

        let challengeData = try decodeBase64Challenge(challengeResponse.challenge)
        let clientDataHash = sha256Data(challengeData)

        let attestationData = try await attestKey(
            keyId: keyId,
            clientDataHash: clientDataHash
        )

        let request = AppAttestAttestationRequest(
            keyId: keyId,
            attestation: attestationData.base64EncodedString(),
            challenge: challengeResponse.challenge
        )

        let response = try await apiClient.post(
            "/api/ios/app-attest/attest",
            body: request,
            headers: [
                "x-client-platform": "ios"
            ],
            as: AppAttestSuccessResponse.self
        )

        if response.ok {
            UserDefaults.standard.set(true, forKey: attestedDefaultsKey)
        }
    }

    func generateAssertion(
        keyId: String,
        challenge: String,
        requestBody: Data,
        method: String,
        path: String
    ) async throws -> String {
        guard service.isSupported else {
            throw AppAttestError.notSupported
        }

        let challengeData = try decodeBase64Challenge(challenge)

        let normalizedMethod = method.uppercased()
        let normalizedPath = normalizePath(path)

        let clientDataHashInput = makeAssertionPayload(
            challenge: challengeData,
            method: normalizedMethod,
            path: normalizedPath,
            requestBody: requestBody
        )

        let clientDataHash = sha256Data(clientDataHashInput)

        let assertionData = try await generateAssertionData(
            keyId: keyId,
            clientDataHash: clientDataHash
        )

        return assertionData.base64EncodedString()
    }

    func resetForDebug() {
        UserDefaults.standard.removeObject(forKey: keyIdDefaultsKey)
        UserDefaults.standard.removeObject(forKey: attestedDefaultsKey)
    }

    // MARK: - Internal helpers

    private func getOrCreateKeyId() async throws -> String {
        if let existing = UserDefaults.standard.string(forKey: keyIdDefaultsKey),
           !existing.isEmpty {
            return existing
        }

        let keyId = try await generateKey()
        UserDefaults.standard.set(keyId, forKey: keyIdDefaultsKey)
        return keyId
    }

    private func decodeBase64Challenge(_ base64: String) throws -> Data {
        guard let data = Data(base64Encoded: base64) else {
            throw AppAttestError.invalidChallenge
        }
        return data
    }

    private func normalizePath(_ path: String) -> String {
        path.hasPrefix("/") ? path : "/\(path)"
    }

    private func makeAssertionPayload(
        challenge: Data,
        method: String,
        path: String,
        requestBody: Data
    ) -> Data {
        var data = Data()

        data.append(challenge)

        if let methodData = method.data(using: .utf8) {
            data.append(methodData)
        }

        data.append(0)

        if let pathData = path.data(using: .utf8) {
            data.append(pathData)
        }

        data.append(0)
        data.append(requestBody)

        return data
    }

    private func sha256Data(_ data: Data) -> Data {
        let digest = SHA256.hash(data: data)
        return Data(digest)
    }

    private func generateKey() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            service.generateKey { keyId, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let keyId, !keyId.isEmpty else {
                    continuation.resume(throwing: AppAttestError.missingKeyId)
                    return
                }

                continuation.resume(returning: keyId)
            }
        }
    }

    private func attestKey(
        keyId: String,
        clientDataHash: Data
    ) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            service.attestKey(keyId, clientDataHash: clientDataHash) { attestation, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let attestation else {
                    continuation.resume(throwing: AppAttestError.invalidAttestationData)
                    return
                }

                continuation.resume(returning: attestation)
            }
        }
    }

    private func generateAssertionData(
        keyId: String,
        clientDataHash: Data
    ) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            service.generateAssertion(keyId, clientDataHash: clientDataHash) { assertion, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let assertion else {
                    continuation.resume(throwing: AppAttestError.invalidAssertionData)
                    return
                }

                continuation.resume(returning: assertion)
            }
        }
    }
}
