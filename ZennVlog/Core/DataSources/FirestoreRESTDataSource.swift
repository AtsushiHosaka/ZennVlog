import Foundation

protocol FirestoreRESTDataSourceProtocol: Sendable {
    func fetchCollection(named collection: String) async throws -> [FirestoreDocument]
    func fetchDocument(collection: String, id: String) async throws -> FirestoreDocument?
}

actor FirestoreRESTDataSource: FirestoreRESTDataSourceProtocol {

    // MARK: - Properties

    private let config: GoogleServiceConfig
    private let httpClient: any HTTPClientProtocol
    private let decoder = JSONDecoder()

    // MARK: - Init

    init(
        config: GoogleServiceConfig,
        httpClient: any HTTPClientProtocol = HTTPClient()
    ) {
        self.config = config
        self.httpClient = httpClient
    }

    // MARK: - FirestoreRESTDataSourceProtocol

    func fetchCollection(named collection: String) async throws -> [FirestoreDocument] {
        let url = try makeCollectionURL(collection: collection)
        let response = try await httpClient.get(url: url, headers: [:])
        let payload = try decoder.decode(FirestoreCollectionResponse.self, from: response.data)
        return payload.documents ?? []
    }

    func fetchDocument(collection: String, id: String) async throws -> FirestoreDocument? {
        let url = try makeDocumentURL(collection: collection, id: id)

        do {
            let response = try await httpClient.get(url: url, headers: [:])
            return try decoder.decode(FirestoreDocument.self, from: response.data)
        } catch let error as HTTPClientError {
            if case .unexpectedStatusCode(let statusCode, _) = error, statusCode == 404 {
                return nil
            }
            throw error
        }
    }

    // MARK: - Private Methods

    private func makeCollectionURL(collection: String) throws -> URL {
        guard var components = URLComponents(
            string: "https://firestore.googleapis.com/v1/projects/\(config.projectID)/databases/(default)/documents/\(collection)"
        ) else {
            throw URLError(.badURL)
        }

        components.queryItems = [
            URLQueryItem(name: "key", value: config.apiKey)
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        return url
    }

    private func makeDocumentURL(collection: String, id: String) throws -> URL {
        guard var components = URLComponents(
            string: "https://firestore.googleapis.com/v1/projects/\(config.projectID)/databases/(default)/documents/\(collection)/\(id)"
        ) else {
            throw URLError(.badURL)
        }

        components.queryItems = [
            URLQueryItem(name: "key", value: config.apiKey)
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        return url
    }
}

struct FirestoreCollectionResponse: Decodable, Sendable {
    let documents: [FirestoreDocument]?
}

struct FirestoreDocument: Decodable, Sendable {
    let name: String
    let fields: [String: FirestoreValue]

    var documentID: String {
        name.split(separator: "/").last.map(String.init) ?? ""
    }
}

enum FirestoreValue: Decodable, Sendable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case array([FirestoreValue])
    case map([String: FirestoreValue])
    case null

    private enum CodingKeys: String, CodingKey {
        case stringValue
        case integerValue
        case doubleValue
        case booleanValue
        case arrayValue
        case mapValue
        case nullValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let value = try container.decodeIfPresent(String.self, forKey: .stringValue) {
            self = .string(value)
            return
        }

        if let value = try container.decodeIfPresent(String.self, forKey: .integerValue),
           let parsed = Int(value) {
            self = .integer(parsed)
            return
        }

        if let value = try container.decodeIfPresent(Double.self, forKey: .doubleValue) {
            self = .double(value)
            return
        }

        if let value = try container.decodeIfPresent(Bool.self, forKey: .booleanValue) {
            self = .boolean(value)
            return
        }

        if let value = try container.decodeIfPresent(FirestoreArrayValue.self, forKey: .arrayValue) {
            self = .array(value.values ?? [])
            return
        }

        if let value = try container.decodeIfPresent(FirestoreMapValue.self, forKey: .mapValue) {
            self = .map(value.fields ?? [:])
            return
        }

        if container.contains(.nullValue) {
            self = .null
            return
        }

        self = .null
    }

    var string: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    var int: Int? {
        switch self {
        case .integer(let value):
            return value
        case .string(let value):
            return Int(value)
        default:
            return nil
        }
    }

    var double: Double? {
        switch self {
        case .double(let value):
            return value
        case .integer(let value):
            return Double(value)
        case .string(let value):
            return Double(value)
        default:
            return nil
        }
    }

    var bool: Bool? {
        guard case .boolean(let value) = self else { return nil }
        return value
    }

    var array: [FirestoreValue]? {
        guard case .array(let values) = self else { return nil }
        return values
    }

    var map: [String: FirestoreValue]? {
        guard case .map(let values) = self else { return nil }
        return values
    }
}

struct FirestoreArrayValue: Decodable, Sendable {
    let values: [FirestoreValue]?
}

struct FirestoreMapValue: Decodable, Sendable {
    let fields: [String: FirestoreValue]?
}
