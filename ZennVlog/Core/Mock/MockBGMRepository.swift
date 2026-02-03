import Foundation

final class MockBGMRepository: BGMRepositoryProtocol, @unchecked Sendable {

    // MARK: - Properties

    private let tracks: [BGMTrack]

    // MARK: - Init

    init() {
        tracks = Self.createMockTracks()
    }

    // MARK: - BGMRepositoryProtocol

    func fetchAll() async throws -> [BGMTrack] {
        try await simulateNetworkDelay()
        return tracks
    }

    func fetch(by id: String) async throws -> BGMTrack? {
        try await simulateNetworkDelay()
        return tracks.first { $0.id == id }
    }

    func downloadURL(for track: BGMTrack) async throws -> URL {
        try await simulateNetworkDelay()
        guard let url = URL(string: "mock://bgm/\(track.id).m4a") else {
            throw BGMRepositoryError.invalidURL(track.storageUrl)
        }
        return url
    }

    // MARK: - Private Methods

    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
    }

    private static func createMockTracks() -> [BGMTrack] {
        [
            BGMTrack(
                id: "bgm-001",
                title: "爽やかな朝",
                description: "明るく前向きなVlogに最適",
                genre: "pop",
                duration: 120,
                storageUrl: "gs://bucket/bgm/morning.m4a",
                tags: ["明るい", "爽やか", "日常"]
            ),
            BGMTrack(
                id: "bgm-002",
                title: "チルな午後",
                description: "落ち着いた雰囲気に",
                genre: "lo-fi",
                duration: 180,
                storageUrl: "gs://bucket/bgm/chill.m4a",
                tags: ["落ち着いた", "リラックス", "カフェ"]
            ),
            BGMTrack(
                id: "bgm-003",
                title: "アドベンチャー",
                description: "旅行やアウトドアに",
                genre: "cinematic",
                duration: 150,
                storageUrl: "gs://bucket/bgm/adventure.m4a",
                tags: ["冒険", "旅行", "ワクワク"]
            ),
            BGMTrack(
                id: "bgm-004",
                title: "ハッピータイム",
                description: "楽しい瞬間を彩る",
                genre: "pop",
                duration: 90,
                storageUrl: "gs://bucket/bgm/happy.m4a",
                tags: ["楽しい", "パーティー", "友達"]
            ),
            BGMTrack(
                id: "bgm-005",
                title: "ノスタルジア",
                description: "思い出を振り返るシーンに",
                genre: "acoustic",
                duration: 200,
                storageUrl: "gs://bucket/bgm/nostalgia.m4a",
                tags: ["懐かしい", "感動", "エモい"]
            )
        ]
    }
}
