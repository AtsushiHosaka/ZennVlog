import Foundation
import FirebaseStorage

protocol StorageRESTDataSourceProtocol: Sendable {
    func downloadObject(
        from storageURL: String,
        cacheDirectory: URL,
        cacheFileName: String
    ) async throws -> URL
}

actor StorageRESTDataSource: StorageRESTDataSourceProtocol {

    // MARK: - Properties

    private let storage: Storage
    private let fileManager: FileManager

    // MARK: - Init

    init(
        storage: Storage = Storage.storage(),
        fileManager: FileManager = .default
    ) {
        self.storage = storage
        self.fileManager = fileManager
    }

    // MARK: - StorageRESTDataSourceProtocol

    func downloadObject(
        from storageURL: String,
        cacheDirectory: URL,
        cacheFileName: String
    ) async throws -> URL {
        let destinationURL = cacheDirectory.appendingPathComponent(cacheFileName)
        if fileManager.fileExists(atPath: destinationURL.path) {
            return destinationURL
        }

        try fileManager.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )

        let storageReference = try reference(from: storageURL)
        try await download(reference: storageReference, to: destinationURL)
        return destinationURL
    }

    // MARK: - Private Methods

    private func reference(from storageURL: String) throws -> StorageReference {
        guard storageURL.hasPrefix("gs://") else {
            throw URLError(.unsupportedURL)
        }
        return storage.reference(forURL: storageURL)
    }

    private func download(reference: StorageReference, to destinationURL: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            _ = reference.write(toFile: destinationURL) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }
}
