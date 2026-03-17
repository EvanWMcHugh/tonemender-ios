import Foundation

enum APIError: LocalizedError {
    case invalidResponse
    case server(statusCode: Int, message: String)
    case decodingFailed
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response."
        case .server(_, let message):
            return message
        case .decodingFailed:
            return "Failed to read the server response."
        case .invalidURL:
            return "Invalid server URL."
        }
    }
}

private struct AppAttestAssertionChallengeResponse: Decodable {
    let challengeId: String
    let challenge: String
}

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil

        session = URLSession(configuration: config)
        decoder = JSONDecoder()
        encoder = JSONEncoder()
    }

    // MARK: - Standard Requests

    func get<T: Decodable>(
        _ path: String,
        as type: T.Type
    ) async throws -> T {
        let request = try makeRequest(path: path, method: "GET")
        return try await perform(request, as: type)
    }

    func get<T: Decodable>(
        _ path: String,
        headers: [String: String],
        as type: T.Type
    ) async throws -> T {
        let request = try makeRequest(path: path, method: "GET", headers: headers)
        return try await perform(request, as: type)
    }

    func post<T: Decodable>(
        _ path: String,
        as type: T.Type
    ) async throws -> T {
        let request = try makeRequest(path: path, method: "POST")
        return try await perform(request, as: type)
    }

    func post<B: Encodable, T: Decodable>(
        _ path: String,
        body: B,
        as type: T.Type
    ) async throws -> T {
        let bodyData = try encoder.encode(body)
        let request = try makeRequest(path: path, method: "POST", body: bodyData)
        return try await perform(request, as: type)
    }

    func post<B: Encodable, T: Decodable>(
        _ path: String,
        body: B,
        headers: [String: String],
        as type: T.Type
    ) async throws -> T {
        let bodyData = try encoder.encode(body)
        let request = try makeRequest(path: path, method: "POST", body: bodyData, headers: headers)
        return try await perform(request, as: type)
    }

    func post<T: Decodable>(
        _ path: String,
        headers: [String: String],
        as type: T.Type
    ) async throws -> T {
        let request = try makeRequest(path: path, method: "POST", headers: headers)
        return try await perform(request, as: type)
    }

    // MARK: - Protected Requests (App Attest)

    func protectedGet<T: Decodable>(
        _ path: String,
        as type: T.Type
    ) async throws -> T {
        let headers = try await appAttestHeaders(
            method: "GET",
            path: path,
            body: nil
        )

        let request = try makeRequest(
            path: path,
            method: "GET",
            headers: headers
        )

        return try await perform(request, as: type)
    }

    func protectedGet<T: Decodable>(
        _ path: String,
        headers: [String: String],
        as type: T.Type
    ) async throws -> T {
        let attestHeaders = try await appAttestHeaders(
            method: "GET",
            path: path,
            body: nil
        )

        let merged = attestHeaders.merging(headers) { _, new in new }

        let request = try makeRequest(
            path: path,
            method: "GET",
            headers: merged
        )

        return try await perform(request, as: type)
    }

    func protectedPost<T: Decodable>(
        _ path: String,
        as type: T.Type
    ) async throws -> T {
        let headers = try await appAttestHeaders(
            method: "POST",
            path: path,
            body: nil
        )

        let request = try makeRequest(
            path: path,
            method: "POST",
            headers: headers
        )

        return try await perform(request, as: type)
    }

    func protectedPost<B: Encodable, T: Decodable>(
        _ path: String,
        body: B,
        as type: T.Type
    ) async throws -> T {
        let bodyData = try encoder.encode(body)

        let headers = try await appAttestHeaders(
            method: "POST",
            path: path,
            body: bodyData
        )

        let request = try makeRequest(
            path: path,
            method: "POST",
            body: bodyData,
            headers: headers
        )

        return try await perform(request, as: type)
    }

    func protectedPost<B: Encodable, T: Decodable>(
        _ path: String,
        body: B,
        headers: [String: String],
        as type: T.Type
    ) async throws -> T {
        let bodyData = try encoder.encode(body)

        let attestHeaders = try await appAttestHeaders(
            method: "POST",
            path: path,
            body: bodyData
        )

        let merged = attestHeaders.merging(headers) { _, new in new }

        let request = try makeRequest(
            path: path,
            method: "POST",
            body: bodyData,
            headers: merged
        )

        return try await perform(request, as: type)
    }

    // MARK: - Request Building

    private func makeRequest(
        path: String,
        method: String,
        body: Data? = nil,
        headers: [String: String] = [:]
    ) throws -> URLRequest {
        let trimmedPath = normalizePath(path)
        let url = AppConfig.baseURL.appendingPathComponent(trimmedPath)

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        return request
    }

    private func normalizePath(_ path: String) -> String {
        path.hasPrefix("/") ? String(path.dropFirst()) : path
    }

    // MARK: - App Attest Preflight

    private func appAttestHeaders(
        method: String,
        path: String,
        body: Data?
    ) async throws -> [String: String] {
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"

        let challengeResponse: AppAttestAssertionChallengeResponse =
            try await fetchAssertionChallenge()

        let appAttest = AppAttestService.shared

        let keyId = try await appAttest.ensureKeyId()
        try await appAttest.ensureAttestedIfNeeded()

        let assertion = try await appAttest.generateAssertion(
            keyId: keyId,
            challenge: challengeResponse.challenge,
            requestBody: body ?? Data(),
            method: method,
            path: normalizedPath
        )

        return [
            "x-client-platform": "ios",
            "x-app-attest-key-id": keyId,
            "x-app-attest-assertion": assertion,
            "x-app-attest-challenge-id": challengeResponse.challengeId
        ]
    }

    private func fetchAssertionChallenge() async throws -> AppAttestAssertionChallengeResponse {
        let request = try makeRequest(
            path: "/api/ios/app-attest/assertion-challenge",
            method: "POST",
            headers: [
                "x-client-platform": "ios"
            ]
        )

        return try await perform(request, as: AppAttestAssertionChallengeResponse.self)
    }

    // MARK: - Response Handling

    private func perform<T: Decodable>(
        _ request: URLRequest,
        as type: T.Type
    ) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let serverMessage = extractServerMessage(from: data) ?? "Something went wrong."
            throw APIError.server(statusCode: httpResponse.statusCode, message: serverMessage)
        }

        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    private func extractServerMessage(from data: Data) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = json["error"] as? String, !error.isEmpty {
                return error
            }

            if let message = json["message"] as? String, !message.isEmpty {
                return message
            }
        }

        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return text
        }

        return nil
    }
}
