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
    private let apiClient: APIClient

    private let keyIdKey = "tm_app_attest_key_id"
    private let attestedKey = "tm_app_attest_attested"

    private init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    private convenience init() {
        self.init(apiClient: APIClient.shared)
    }

    var isSupported: Bool {
        service.isSupported
    }

    // MARK: - Public API

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

        if UserDefaults.standard.bool(forKey: attestedKey) {
            return
        }

        let keyId = try await getOrCreateKeyId()

        let challengeResponse = try await apiClient.post(
            "/api/ios/app-attest/challenge",
            headers: ["x-client-platform": "ios"],
            as: AppAttestChallengeResponse.self
        )

        let challengeData = try decodeBase64(challengeResponse.challenge)
        let clientDataHash = sha256(challengeData)

        let attestation = try await attestKey(
            keyId: keyId,
            clientDataHash: clientDataHash
        )

        let request = AppAttestAttestationRequest(
            keyId: keyId,
            attestation: attestation.base64EncodedString(),
            challenge: challengeResponse.challenge
        )

        let response = try await apiClient.post(
            "/api/ios/app-attest/attest",
            body: request,
            headers: ["x-client-platform": "ios"],
            as: AppAttestSuccessResponse.self
        )

        if response.ok == true {
            UserDefaults.standard.set(true, forKey: attestedKey)
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

        let challengeData = try decodeBase64(challenge)

        let payload = makeAssertionPayload(
            challenge: challengeData,
            method: method.uppercased(),
            path: normalizePath(path),
            body: requestBody
        )

        let clientDataHash = sha256(payload)

        let assertion = try await generateAssertionData(
            keyId: keyId,
            clientDataHash: clientDataHash
        )

        return assertion.base64EncodedString()
    }

    func resetForDebug() {
        UserDefaults.standard.removeObject(forKey: keyIdKey)
        UserDefaults.standard.removeObject(forKey: attestedKey)
    }

    // MARK: - Private

    private func getOrCreateKeyId() async throws -> String {
        if let existing = UserDefaults.standard.string(forKey: keyIdKey),
           !existing.isEmpty {
            return existing
        }

        let keyId = try await generateKey()
        UserDefaults.standard.set(keyId, forKey: keyIdKey)
        return keyId
    }

    private func decodeBase64(_ base64: String) throws -> Data {
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
        body: Data
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
        data.append(body)

        return data
    }

    private func sha256(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
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
            service.attestKey(keyId, clientDataHash: clientDataHash) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let data else {
                    continuation.resume(throwing: AppAttestError.invalidAttestationData)
                    return
                }

                continuation.resume(returning: data)
            }
        }
    }

    private func generateAssertionData(
        keyId: String,
        clientDataHash: Data
    ) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            service.generateAssertion(keyId, clientDataHash: clientDataHash) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let data else {
                    continuation.resume(throwing: AppAttestError.invalidAssertionData)
                    return
                }

                continuation.resume(returning: data)
            }
        }
    }
}
