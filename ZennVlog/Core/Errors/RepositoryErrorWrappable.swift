import Foundation

protocol RepositoryErrorWrappable: Error {
    static func unknown(underlying: Error) -> Self
}

extension RepositoryErrorWrappable {
    static func wrap(_ error: Error) -> Self {
        if let typedError = error as? Self {
            return typedError
        }
        return .unknown(underlying: error)
    }

    static func execute<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch {
            throw wrap(error)
        }
    }
}
