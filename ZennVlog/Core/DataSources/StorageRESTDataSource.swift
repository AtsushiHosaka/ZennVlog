import Foundation

protocol StorageRESTDataSourceProtocol: Sendable {
    func downloadObject(
        from storageURL: String,
        cacheDirectory: URL,
        cacheFileName: String
    ) async throws -> URL
}

actor StorageRESTDataSource: StorageRESTDataSourceProtocol {

    // MARK: - Properties

    private let config: GoogleServiceConfig
    private let httpClient: any HTTPClientProtocol
    private let fileManager: FileManager

    // MARK: - Init

    init(
        config: GoogleServiceConfig,
        httpClient: any HTTPClientProtocol = HTTPClient(),
        fileManager: FileManager = .default
    ) {
        self.config = config
        self.httpClient = httpClient
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

        let requestURL = try makeDownloadURL(storageURL: storageURL)
        let response = try await httpClient.get(url: requestURL, headers: [:])

        try response.data.write(to: destinationURL, options: .atomic)
        return destinationURL
    }

    // MARK: - Private Methods

    private func makeDownloadURL(storageURL: String) throws -> URL {
        let (bucket, objectPath) = try parseStorageURL(storageURL)
        let encodedPath = objectPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? objectPath

        guard var components = URLComponents(
            string: "https://firebasestorage.googleapis.com/v0/b/\(bucket)/o/\(encodedPath)"
        ) else {
            throw URLError(.badURL)
        }

        components.queryItems = [
            URLQueryItem(name: "alt", value: "media"),
            URLQueryItem(name: "key", value: config.apiKey)
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        return url
    }

    private func parseStorageURL(_ storageURL: String) throws -> (bucket: String, objectPath: String) {
        guard storageURL.hasPrefix("gs://") else {
            throw URLError(.unsupportedURL)
        }

        let stripped = storageURL.replacingOccurrences(of: "gs://", with: "")
        let components = stripped.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true)

        guard let first = components.first else {
            throw URLError(.badURL)
        }

        let bucket = String(first)
        let objectPath = components.count > 1 ? String(components[1]) : ""

        guard !bucket.isEmpty, !objectPath.isEmpty else {
            throw URLError(.badURL)
        }

        return (bucket, objectPath)
    }
}
