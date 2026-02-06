import Foundation
import Testing
@testable import ZennVlog

@Suite("DownloadBGMUseCase テスト")
@MainActor
struct DownloadBGMUseCaseTests {
    let useCase: DownloadBGMUseCase
    let mockRepository: MockBGMRepository

    init() async throws {
        mockRepository = MockBGMRepository()
        useCase = DownloadBGMUseCase(repository: mockRepository)
    }

    @Test("BGMをダウンロードしてURLを返す")
    func downloadBGM() async throws {
        let track = BGMTrack(
            id: "bgm-001",
            title: "爽やかな朝",
            description: "明るく前向きなVlogに最適",
            genre: "pop",
            duration: 120,
            storageUrl: "gs://bucket/bgm/morning.m4a",
            tags: ["明るい"]
        )

        let url = try await useCase.execute(track: track)
        #expect(url.scheme == "mock")
    }

    @Test("ダウンロードURLがmockスキームである")
    func downloadURLSchemeisMock() async throws {
        let tracks = try await mockRepository.fetchAll()
        guard let track = tracks.first else {
            throw TestError.noTracksFound
        }

        let url = try await useCase.execute(track: track)
        #expect(url.scheme == "mock")
        #expect(url.absoluteString.contains(track.id))
    }

    @Test("各BGMトラックをダウンロードできる")
    func downloadEachTrack() async throws {
        let tracks = try await mockRepository.fetchAll()

        for track in tracks {
            let url = try await useCase.execute(track: track)
            #expect(!url.absoluteString.isEmpty)
            #expect(url.scheme == "mock")
        }
    }

    @Test("同じトラックを複数回ダウンロードしても一貫したURLを返す")
    func consistentDownloadURL() async throws {
        let track = BGMTrack(
            id: "bgm-001",
            title: "爽やかな朝",
            description: "明るく前向きなVlogに最適",
            genre: "pop",
            duration: 120,
            storageUrl: "gs://bucket/bgm/morning.m4a",
            tags: ["明るい"]
        )

        let url1 = try await useCase.execute(track: track)
        let url2 = try await useCase.execute(track: track)
        #expect(url1.absoluteString == url2.absoluteString)
    }
}

enum TestError: Error {
    case noTracksFound
}
