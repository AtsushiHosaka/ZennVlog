import Foundation
import Testing
@testable import ZennVlog

@Suite("AnalyzeVideoUseCase Tests")
@MainActor
struct AnalyzeVideoUseCaseTests {

    let useCase: AnalyzeVideoUseCase
    let mockRepository: MockGeminiRepository

    init() async {
        mockRepository = MockGeminiRepository()
        useCase = AnalyzeVideoUseCase(repository: mockRepository)
    }

    // MARK: - 基本的な動画分析テスト

    @Test("動画を正しく分析して結果を返す")
    func 動画を正しく分析して結果を返す() async throws {
        // Given: 動画URL
        let videoURL = URL(string: "mock://video/test.mp4")!

        // When: 動画を分析
        let result = try await useCase.execute(videoURL: videoURL)

        // Then: 分析結果が返される
        #expect(!result.segments.isEmpty)
        #expect(result.segments.count == 3)
    }

    @Test("セグメント情報が正しく含まれる")
    func セグメント情報が正しく含まれる() async throws {
        // Given: 動画URL
        let videoURL = URL(string: "mock://video/test.mp4")!

        // When: 動画を分析
        let result = try await useCase.execute(videoURL: videoURL)

        // Then: 各セグメントに必要な情報が含まれる
        let firstSegment = try #require(result.segments.first)
        #expect(firstSegment.startSeconds == 0)
        #expect(firstSegment.endSeconds == 5)
        #expect(!firstSegment.description.isEmpty)
    }

    @Test("複数のセグメントを正しく識別する")
    func 複数のセグメントを正しく識別する() async throws {
        // Given: 動画URL
        let videoURL = URL(string: "mock://video/test.mp4")!

        // When: 動画を分析
        let result = try await useCase.execute(videoURL: videoURL)

        // Then: 複数のセグメントが時系列順に並んでいる
        #expect(result.segments.count == 3)

        let segment1 = result.segments[0]
        let segment2 = result.segments[1]
        let segment3 = result.segments[2]

        #expect(segment1.startSeconds == 0)
        #expect(segment1.endSeconds == 5)

        #expect(segment2.startSeconds == 5)
        #expect(segment2.endSeconds == 12)

        #expect(segment3.startSeconds == 12)
        #expect(segment3.endSeconds == 20)
    }

    @Test("セグメントの説明が含まれる")
    func セグメントの説明が含まれる() async throws {
        // Given: 動画URL
        let videoURL = URL(string: "mock://video/test.mp4")!

        // When: 動画を分析
        let result = try await useCase.execute(videoURL: videoURL)

        // Then: 各セグメントに説明が含まれる
        #expect(result.segments[0].description.contains("人物"))
        #expect(result.segments[1].description.contains("風景"))
        #expect(result.segments[2].description.contains("食事"))
    }

    // MARK: - 様々な動画URLのテスト

    @Test("ローカルファイルURLでも動作する")
    func ローカルファイルURLでも動作する() async throws {
        // Given: ローカルファイルURL
        let videoURL = URL(fileURLWithPath: "/tmp/test_video.mp4")

        // When: 動画を分析
        let result = try await useCase.execute(videoURL: videoURL)

        // Then: 分析結果が返される
        #expect(!result.segments.isEmpty)
    }

    @Test("異なる動画URLでも同じ構造の結果を返す")
    func 異なる動画URLでも同じ構造の結果を返す() async throws {
        // Given: 異なる動画URL
        let videoURL1 = URL(string: "mock://video/video1.mp4")!
        let videoURL2 = URL(string: "mock://video/video2.mp4")!

        // When: 2つの動画を分析
        let result1 = try await useCase.execute(videoURL: videoURL1)
        let result2 = try await useCase.execute(videoURL: videoURL2)

        // Then: 同じ構造の結果が返される（Mockなので）
        #expect(result1.segments.count == result2.segments.count)
        #expect(result1.segments.count == 3)
    }

    // MARK: - エラーハンドリングテスト

    @Test("無効なURLでもエラーをthrowしない")
    func 無効なURLでもエラーをthrowしない() async throws {
        // Given: 無効なURL（Mockは常に成功を返す）
        let videoURL = URL(string: "invalid://url")!

        // When & Then: エラーをthrowしない（Mockの動作）
        let result = try await useCase.execute(videoURL: videoURL)
        #expect(!result.segments.isEmpty)
    }

    // MARK: - パフォーマンステスト

    @Test("適切な時間内に分析が完了する")
    func 適切な時間内に分析が完了する() async throws {
        // Given: 動画URL
        let videoURL = URL(string: "mock://video/test.mp4")!

        // When: 動画を分析して時間を計測
        let startTime = ContinuousClock.now
        _ = try await useCase.execute(videoURL: videoURL)
        let elapsed = ContinuousClock.now - startTime

        // Then: 5秒以内に完了する（長い遅延2秒 + マージン）
        #expect(elapsed < .seconds(5))
    }

    @Test("複数の動画を連続で分析できる")
    func 複数の動画を連続で分析できる() async throws {
        // Given: 複数の動画URL
        let videoURLs = [
            URL(string: "mock://video/video1.mp4")!,
            URL(string: "mock://video/video2.mp4")!,
            URL(string: "mock://video/video3.mp4")!
        ]

        // When: 連続で分析
        for videoURL in videoURLs {
            let result = try await useCase.execute(videoURL: videoURL)

            // Then: すべて正しく分析される
            #expect(result.segments.count == 3)
        }
    }

    // MARK: - セグメントの時系列テスト

    @Test("セグメントが重複していない")
    func セグメントが重複していない() async throws {
        // Given: 動画URL
        let videoURL = URL(string: "mock://video/test.mp4")!

        // When: 動画を分析
        let result = try await useCase.execute(videoURL: videoURL)

        // Then: セグメントの時間帯が重複していない
        for i in 0..<result.segments.count - 1 {
            let currentSegment = result.segments[i]
            let nextSegment = result.segments[i + 1]

            // 現在のセグメントの終了時刻が次のセグメントの開始時刻以下
            #expect(currentSegment.endSeconds <= nextSegment.startSeconds)
        }
    }

    @Test("セグメントが昇順にソートされている")
    func セグメントが昇順にソートされている() async throws {
        // Given: 動画URL
        let videoURL = URL(string: "mock://video/test.mp4")!

        // When: 動画を分析
        let result = try await useCase.execute(videoURL: videoURL)

        // Then: セグメントが開始時刻の昇順にソートされている
        for i in 0..<result.segments.count - 1 {
            let currentSegment = result.segments[i]
            let nextSegment = result.segments[i + 1]

            #expect(currentSegment.startSeconds < nextSegment.startSeconds)
        }
    }

    @Test("すべてのセグメントが正の時間を持つ")
    func すべてのセグメントが正の時間を持つ() async throws {
        // Given: 動画URL
        let videoURL = URL(string: "mock://video/test.mp4")!

        // When: 動画を分析
        let result = try await useCase.execute(videoURL: videoURL)

        // Then: すべてのセグメントが正の時間を持つ
        for segment in result.segments {
            #expect(segment.startSeconds >= 0)
            #expect(segment.endSeconds > segment.startSeconds)
        }
    }
}
