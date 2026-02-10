import Foundation

actor FirestoreBGMRepository: BGMRepositoryProtocol {

    // MARK: - Properties

    private let dataSource: any FirestoreRESTDataSourceProtocol
    private let storageDataSource: any StorageRESTDataSourceProtocol
    private let fileManager: FileManager

    // MARK: - Init

    init(
        dataSource: any FirestoreRESTDataSourceProtocol,
        storageDataSource: any StorageRESTDataSourceProtocol,
        fileManager: FileManager = .default
    ) {
        self.dataSource = dataSource
        self.storageDataSource = storageDataSource
        self.fileManager = fileManager
    }

    convenience init(
        config: GoogleServiceConfig = GoogleServiceConfigLoader.load(),
        httpClient: any HTTPClientProtocol = HTTPClient(),
        fileManager: FileManager = .default
    ) {
        self.init(
            dataSource: FirestoreRESTDataSource(config: config, httpClient: httpClient),
            storageDataSource: StorageRESTDataSource(config: config, httpClient: httpClient),
            fileManager: fileManager
        )
    }

    // MARK: - BGMRepositoryProtocol

    func fetchAll() async throws -> [BGMTrack] {
        do {
            let documents = try await dataSource.fetchCollection(named: "bgm_tracks")
            return try documents
                .map(decodeTrack)
                .sorted { $0.id < $1.id }
        } catch let error as BGMRepositoryError {
            throw error
        } catch {
            throw BGMRepositoryError.fetchFailed(underlying: error)
        }
    }

    func fetch(by id: String) async throws -> BGMTrack? {
        do {
            guard let document = try await dataSource.fetchDocument(collection: "bgm_tracks", id: id) else {
                return nil
            }
            return try decodeTrack(document)
        } catch let error as BGMRepositoryError {
            throw error
        } catch {
            throw BGMRepositoryError.fetchFailed(underlying: error)
        }
    }

    func downloadURL(for track: BGMTrack) async throws -> URL {
        do {
            let cachesDirectory = try cachesDirectory()
            let bgmDirectory = cachesDirectory.appendingPathComponent("BGM", isDirectory: true)
            let fileName = "\(track.id).m4a"
            let localURL = bgmDirectory.appendingPathComponent(fileName)

            if fileManager.fileExists(atPath: localURL.path) {
                return localURL
            }

            return try await storageDataSource.downloadObject(
                from: track.storageUrl,
                cacheDirectory: bgmDirectory,
                cacheFileName: fileName
            )
        } catch {
            throw BGMRepositoryError.downloadFailed(underlying: error)
        }
    }

    // MARK: - Private Methods

    private func decodeTrack(_ document: FirestoreDocument) throws -> BGMTrack {
        let fields = document.fields

        guard let title = fields["title"]?.string,
              let description = fields["description"]?.string,
              let genre = fields["genre"]?.string,
              let duration = fields["duration"]?.int,
              let storageUrl = fields["storageUrl"]?.string else {
            throw BGMRepositoryError.fetchFailed(
                underlying: NSError(domain: "FirestoreBGMRepository", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid bgm track fields"
                ])
            )
        }

        let tags = fields["tags"]?.array?.compactMap { $0.string } ?? []

        return BGMTrack(
            id: document.documentID,
            title: title,
            description: description,
            genre: genre,
            duration: duration,
            storageUrl: storageUrl,
            tags: tags
        )
    }

    private func cachesDirectory() throws -> URL {
        guard let url = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "FirestoreBGMRepository", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Caches directory not found"
            ])
        }
        return url
    }
}
