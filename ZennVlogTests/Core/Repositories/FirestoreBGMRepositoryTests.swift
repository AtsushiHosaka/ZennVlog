import Foundation
import Testing
@testable import ZennVlog

private actor BGMDataSourceStub: FirestoreRESTDataSourceProtocol {
    var documents: [FirestoreDocument] = []

    func setDocuments(_ value: [FirestoreDocument]) {
        documents = value
    }

    func fetchCollection(named collection: String) async throws -> [FirestoreDocument] {
        documents
    }

    func fetchDocument(collection: String, id: String) async throws -> FirestoreDocument? {
        documents.first { $0.documentID == id }
    }
}

private actor StorageDataSourceStub: StorageRESTDataSourceProtocol {
    var responseURL: URL?
    var shouldThrow: Bool = false
    var downloadCallCount: Int = 0

    func setResponseURL(_ value: URL) {
        responseURL = value
    }

    func setShouldThrow(_ value: Bool) {
        shouldThrow = value
    }

    func callCount() -> Int {
        downloadCallCount
    }

    func downloadObject(from storageURL: String, cacheDirectory: URL, cacheFileName: String) async throws -> URL {
        downloadCallCount += 1

        if shouldThrow {
            throw URLError(.cannotLoadFromNetwork)
        }

        if let responseURL {
            return responseURL
        }

        let target = cacheDirectory.appendingPathComponent(cacheFileName)
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try Data("bgm".utf8).write(to: target)
        return target
    }
}

@Suite("FirestoreBGMRepository Tests")
struct FirestoreBGMRepositoryTests {

    private func makeTrackDocument(id: String = "bgm-001") -> FirestoreDocument {
        FirestoreDocument(
            name: "projects/demo/databases/(default)/documents/bgm_tracks/\(id)",
            fields: [
                "title": .string("Track"),
                "description": .string("desc"),
                "genre": .string("pop"),
                "duration": .integer(120),
                "storageUrl": .string("gs://bucket/bgm/track.m4a"),
                "tags": .array([.string("tag1")])
            ]
        )
    }

    @Test("fetchAll decodes tracks")
    func fetchAllDecodesTracks() async throws {
        let dataSource = BGMDataSourceStub()
        let storage = StorageDataSourceStub()
        await dataSource.setDocuments([makeTrackDocument()])

        let repository = FirestoreBGMRepository(
            dataSource: dataSource,
            storageDataSource: storage
        )

        let tracks = try await repository.fetchAll()

        #expect(tracks.count == 1)
        #expect(tracks[0].id == "bgm-001")
        #expect(tracks[0].tags == ["tag1"])
    }

    @Test("downloadURL uses cache when file exists")
    func downloadURLUsesCache() async throws {
        let dataSource = BGMDataSourceStub()
        let storage = StorageDataSourceStub()

        let repository = FirestoreBGMRepository(
            dataSource: dataSource,
            storageDataSource: storage
        )

        let track = BGMTrack(
            id: "cache-hit",
            title: "Track",
            description: "desc",
            genre: "pop",
            duration: 100,
            storageUrl: "gs://bucket/bgm/cache-hit.m4a",
            tags: []
        )

        let cacheDir = try #require(FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first)
        let localDir = cacheDir.appendingPathComponent("BGM", isDirectory: true)
        let localFile = localDir.appendingPathComponent("cache-hit.m4a")
        try FileManager.default.createDirectory(at: localDir, withIntermediateDirectories: true)
        try Data("cached".utf8).write(to: localFile)

        let result = try await repository.downloadURL(for: track)

        #expect(result.path == localFile.path)
        #expect(await storage.callCount() == 0)

        try? FileManager.default.removeItem(at: localFile)
    }

    @Test("downloadURL wraps download failure")
    func downloadURLWrapsFailure() async throws {
        let dataSource = BGMDataSourceStub()
        let storage = StorageDataSourceStub()
        await storage.setShouldThrow(true)

        let repository = FirestoreBGMRepository(
            dataSource: dataSource,
            storageDataSource: storage
        )

        let track = BGMTrack(
            id: "bgm-err",
            title: "Track",
            description: "desc",
            genre: "pop",
            duration: 100,
            storageUrl: "gs://bucket/bgm/err.m4a",
            tags: []
        )

        do {
            _ = try await repository.downloadURL(for: track)
            #expect(Bool(false), "downloadFailed should be thrown")
        } catch let error as BGMRepositoryError {
            switch error {
            case .downloadFailed:
                #expect(Bool(true))
            default:
                #expect(Bool(false), "unexpected error type")
            }
        }
    }
}
