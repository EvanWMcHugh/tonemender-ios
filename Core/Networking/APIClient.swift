import Foundation

enum APIError: LocalizedError {
    case invalidResponse
    case invalidStatusCode(Int)
    case server(statusCode: Int, message: String)
    case decodingFailed
    case invalidURL
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response."
        case .invalidStatusCode(let code):
            return "Unexpected server status code: \(code)."
        case .server(_, let message):
            return message
        case .decodingFailed:
            return "Failed to read the server response."
        case .invalidURL:
            return "Invalid server URL."
        case .emptyResponse:
            return "The server returned an empty response."
        }
    }
}

private struct AppAttestAssertionChallengeResponse: Decodable {
    let challengeId: String
    let challenge: String
}

struct EmptyResponse: Decodable {}

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
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60

        session = URLSession(configuration: config)

        let decoder = JSONDecoder()
        self.decoder = decoder

        let encoder = JSONEncoder()
        self.encoder = encoder
    }

    // MARK: - Standard Requests

    func get<T: Decodable>(
        _ path: String,
        as type: T.Type
    ) async throws -> T {
        let request = try makeRequest(path: path, method: HTTPMethod.get.rawValue)
        return try await perform(request, as: type)
    }

    func get<T: Decodable>(
        _ path: String,
        headers: [String: String],
        as type: T.Type
    ) async throws -> T {
        let request = try makeRequest(
            path: path,
            method: HTTPMethod.get.rawValue,
            headers: headers
        )
        return try await perform(request, as: type)
    }

    func post<T: Decodable>(
        _ path: String,
        as type: T.Type
    ) async throws -> T {
        let request = try makeRequest(path: path, method: HTTPMethod.post.rawValue)
        return try await perform(request, as: type)
    }

    func post<B: Encodable, T: Decodable>(
        _ path: String,
        body: B,
        as type: T.Type
    ) async throws -> T {
        let bodyData = try encoder.encode(body)
        let request = try makeRequest(
            path: path,
            method: HTTPMethod.post.rawValue,
            body: bodyData
        )
        return try await perform(request, as: type)
    }

    func post<B: Encodable, T: Decodable>(
        _ path: String,
        body: B,
        headers: [String: String],
        as type: T.Type
    ) async throws -> T {
        let bodyData = try encoder.encode(body)
        let request = try makeRequest(
            path: path,
            method: HTTPMethod.post.rawValue,
            body: bodyData,
            headers: headers
        )
        return try await perform(request, as: type)
    }

    func post<T: Decodable>(
        _ path: String,
        headers: [String: String],
        as type: T.Type
    ) async throws -> T {
        let request = try makeRequest(
            path: path,
            method: HTTPMethod.post.rawValue,
            headers: headers
        )
        return try await perform(request, as: type)
    }

    // MARK: - Protected Requests (App Attest)

    func protectedGet<T: Decodable>(
        _ path: String,
        as type: T.Type
    ) async throws -> T {
        let attestHeaders = try await appAttestHeaders(
            method: HTTPMethod.get.rawValue,
            path: path,
            body: nil
        )

        let request = try makeRequest(
            path: path,
            method: HTTPMethod.get.rawValue,
            headers: attestHeaders
        )

        return try await perform(request, as: type)
    }

    func protectedGet<T: Decodable>(
        _ path: String,
        headers: [String: String],
        as type: T.Type
    ) async throws -> T {
        let attestHeaders = try await appAttestHeaders(
            method: HTTPMethod.get.rawValue,
            path: path,
            body: nil
        )

        let mergedHeaders = mergedHeaders(base: attestHeaders, override: headers)

        let request = try makeRequest(
            path: path,
            method: HTTPMethod.get.rawValue,
            headers: mergedHeaders
        )

        return try await perform(request, as: type)
    }

    func protectedPost<T: Decodable>(
        _ path: String,
        as type: T.Type
    ) async throws -> T {
        let attestHeaders = try await appAttestHeaders(
            method: HTTPMethod.post.rawValue,
            path: path,
            body: nil
        )

        let request = try makeRequest(
            path: path,
            method: HTTPMethod.post.rawValue,
            headers: attestHeaders
        )

        return try await perform(request, as: type)
    }

    func protectedPost<B: Encodable, T: Decodable>(
        _ path: String,
        body: B,
        as type: T.Type
    ) async throws -> T {
        let bodyData = try encoder.encode(body)

        let attestHeaders = try await appAttestHeaders(
            method: HTTPMethod.post.rawValue,
            path: path,
            body: bodyData
        )

        let request = try makeRequest(
            path: path,
            method: HTTPMethod.post.rawValue,
            body: bodyData,
            headers: attestHeaders
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
            method: HTTPMethod.post.rawValue,
            path: path,
            body: bodyData
        )

        let mergedHeaders = mergedHeaders(base: attestHeaders, override: headers)

        let request = try makeRequest(
            path: path,
            method: HTTPMethod.post.rawValue,
            body: bodyData,
            headers: mergedHeaders
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
        let normalizedPath = normalizeRelativePath(path)

        guard let url = URL(string: normalizedPath, relativeTo: AppConfig.baseURL)?.absoluteURL else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.cachePolicy = .reloadIgnoringLocalCacheData

        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ios", forHTTPHeaderField: "x-client-platform")

        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        return request
    }

    private func normalizeRelativePath(_ path: String) -> String {
        path.hasPrefix("/") ? String(path.dropFirst()) : path
    }

    private func normalizedAbsolutePath(_ path: String) -> String {
        path.hasPrefix("/") ? path : "/\(path)"
    }

    private func mergedHeaders(
        base: [String: String],
        override: [String: String]
    ) -> [String: String] {
        base.merging(override) { _, new in new }
    }

    // MARK: - App Attest

    private func appAttestHeaders(
        method: String,
        path: String,
        body: Data?
    ) async throws -> [String: String] {
        let normalizedPath = normalizedAbsolutePath(path)

        let challengeResponse = try await fetchAssertionChallenge()

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
            method: HTTPMethod.post.rawValue
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
            throw APIError.server(
                statusCode: httpResponse.statusCode,
                message: serverMessage
            )
        }

        if type == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        guard !data.isEmpty else {
            throw APIError.emptyResponse
        }

        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    private func extractServerMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = json["error"] as? String, !error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return error
            }

            if let message = json["message"] as? String, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return message
            }
        }

        if let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return text
        }

        return nil
    }
}

// MARK: - HTTP Method

private enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}
