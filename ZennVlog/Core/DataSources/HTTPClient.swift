import Foundation

struct HTTPResponse: Sendable {
    let data: Data
    let statusCode: Int
}

enum HTTPClientError: Error, LocalizedError {
    case invalidResponse
    case unexpectedStatusCode(Int, Data)
    case transport(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid HTTP response"
        case .unexpectedStatusCode(let statusCode, _):
            return "Unexpected HTTP status code: \(statusCode)"
        case .transport(let error):
            return error.localizedDescription
        }
    }
}

protocol HTTPClientProtocol: Sendable {
    func get(url: URL, headers: [String: String]) async throws -> HTTPResponse
    func post(url: URL, body: Data, headers: [String: String]) async throws -> HTTPResponse
}

actor HTTPClient: HTTPClientProtocol {

    // MARK: - Properties

    private let session: URLSession

    // MARK: - Init

    init(session: URLSession = URLSession(configuration: .default)) {
        self.session = session
    }

    // MARK: - HTTPClientProtocol

    func get(url: URL, headers: [String: String] = [:]) async throws -> HTTPResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        return try await execute(request)
    }

    func post(url: URL, body: Data, headers: [String: String] = [:]) async throws -> HTTPResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        return try await execute(request)
    }

    // MARK: - Private Methods

    private func execute(_ request: URLRequest) async throws -> HTTPResponse {
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HTTPClientError.invalidResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw HTTPClientError.unexpectedStatusCode(httpResponse.statusCode, data)
            }

            return HTTPResponse(data: data, statusCode: httpResponse.statusCode)
        } catch let error as HTTPClientError {
            throw error
        } catch {
            throw HTTPClientError.transport(underlying: error)
        }
    }
}
