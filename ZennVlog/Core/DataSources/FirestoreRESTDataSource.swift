import Foundation
import FirebaseFirestore

protocol FirestoreRESTDataSourceProtocol: Sendable {
    func fetchCollection(named collection: String) async throws -> [FirestoreDocument]
    func fetchDocument(collection: String, id: String) async throws -> FirestoreDocument?
}

actor FirestoreRESTDataSource: FirestoreRESTDataSourceProtocol {

    // MARK: - Properties

    private let firestore: Firestore

    // MARK: - Init

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    // MARK: - FirestoreRESTDataSourceProtocol

    func fetchCollection(named collection: String) async throws -> [FirestoreDocument] {
        let snapshot = try await getDocuments(for: firestore.collection(collection))
        return try snapshot.documents.map { document in
            try convert(document: document)
        }
    }

    func fetchDocument(collection: String, id: String) async throws -> FirestoreDocument? {
        let reference = firestore.collection(collection).document(id)
        let snapshot = try await getDocument(for: reference)
        guard snapshot.exists else {
            return nil
        }
        return try convert(document: snapshot)
    }

    // MARK: - Private Methods

    private func getDocuments(for collection: CollectionReference) async throws -> QuerySnapshot {
        try await withCheckedThrowingContinuation { continuation in
            collection.getDocuments { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let snapshot else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }
                continuation.resume(returning: snapshot)
            }
        }
    }

    private func getDocument(for document: DocumentReference) async throws -> DocumentSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            document.getDocument { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let snapshot else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }
                continuation.resume(returning: snapshot)
            }
        }
    }

    private func convert(document: DocumentSnapshot) throws -> FirestoreDocument {
        guard let data = document.data() else {
            return FirestoreDocument(
                name: document.reference.path,
                fields: [:]
            )
        }

        return FirestoreDocument(
            name: document.reference.path,
            fields: try convert(map: data)
        )
    }
    
    private func convert(map: [String: Any]) throws -> [String: FirestoreValue] {
        var result: [String: FirestoreValue] = [:]
        for (key, value) in map {
            result[key] = try convert(value: value)
        }
        return result
    }

    private func convert(value: Any) throws -> FirestoreValue {
        if let stringValue = value as? String {
            return .string(stringValue)
        }
        if let intValue = value as? Int {
            return .integer(intValue)
        }
        if let int64Value = value as? Int64 {
            return .integer(Int(int64Value))
        }
        if let doubleValue = value as? Double {
            return .double(doubleValue)
        }
        if let boolValue = value as? Bool {
            return .boolean(boolValue)
        }
        if let listValue = value as? [Any] {
            return .array(try listValue.map(convert(value:)))
        }
        if let mapValue = value as? [String: Any] {
            return .map(try convert(map: mapValue))
        }
        if value is NSNull {
            return .null
        }
        throw NSError(
            domain: "FirestoreRESTDataSource",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Unsupported Firestore value type: \(type(of: value))"]
        )
    }
}

struct FirestoreDocument: Sendable {
    let name: String
    let fields: [String: FirestoreValue]

    var documentID: String {
        name.split(separator: "/").last.map(String.init) ?? ""
    }
}

enum FirestoreValue: Sendable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case array([FirestoreValue])
    case map([String: FirestoreValue])
    case null

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
