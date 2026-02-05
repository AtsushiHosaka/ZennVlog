import Testing
@testable import ZennVlog

@Suite("FetchBGMTracksUseCase テスト")
@MainActor
struct FetchBGMTracksUseCaseTests {
    let useCase: FetchBGMTracksUseCase
    let mockRepository: MockBGMRepository

    init() async throws {
        mockRepository = MockBGMRepository()
        useCase = FetchBGMTracksUseCase(repository: mockRepository)
    }

    @Test("すべてのBGMトラックを取得できる")
    func fetchAllTracks() async throws {
        let tracks = try await useCase.execute()
        #expect(!tracks.isEmpty)
    }

    @Test("5つのトラックが返される")
    func fetchFiveTracks() async throws {
        let tracks = try await useCase.execute()
        #expect(tracks.count == 5)
    }

    @Test("各トラックに必要な情報が含まれる")
    func trackHasRequiredFields() async throws {
        let tracks = try await useCase.execute()
        for track in tracks {
            #expect(!track.id.isEmpty)
            #expect(!track.title.isEmpty)
            #expect(!track.genre.isEmpty)
            #expect(!track.description.isEmpty)
            #expect(track.duration > 0)
            #expect(!track.tags.isEmpty)
        }
    }

    @Test("爽やかな朝トラックが含まれる")
    func containsMorningTrack() async throws {
        let tracks = try await useCase.execute()
        let morningTrack = tracks.first { $0.id == "bgm-001" }
        #expect(morningTrack != nil)
        #expect(morningTrack?.title == "爽やかな朝")
    }

    @Test("複数回呼び出しても一貫した結果を返す")
    func consistentResults() async throws {
        let tracks1 = try await useCase.execute()
        let tracks2 = try await useCase.execute()
        #expect(tracks1.count == tracks2.count)
        #expect(tracks1.map { $0.id } == tracks2.map { $0.id })
    }
}
