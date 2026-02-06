import Foundation
import Testing
@testable import ZennVlog

// MARK: - MockVideoExporter

final class MockVideoExporter: VideoExporterProtocol, @unchecked Sendable {
    var shouldThrowError = false
    var exportCallCount = 0
    var lastVideoAssetsCount = 0
    var lastSubtitlesCount = 0
    var lastSegmentsCount = 0
    var lastBGMURL: URL?
    var lastBGMVolume: Float = 0

    func export(
        videoAssets: [VideoAsset],
        subtitles: [Subtitle],
        segments: [Segment],
        bgmURL: URL?,
        bgmVolume: Float,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        exportCallCount += 1
        lastVideoAssetsCount = videoAssets.count
        lastSubtitlesCount = subtitles.count
        lastSegmentsCount = segments.count
        lastBGMURL = bgmURL
        lastBGMVolume = bgmVolume

        if shouldThrowError {
            throw VideoExporter.VideoExporterError.exportSessionFailed("Mock error")
        }

        // 進捗をシミュレート
        for progress in stride(from: 0.0, through: 1.0, by: 0.25) {
            progressHandler(progress)
        }

        return URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mock_export.mp4")
    }
}

// MARK: - ExportVideoUseCaseTests

@Suite("ExportVideoUseCase テスト")
@MainActor
struct ExportVideoUseCaseTests {
    let useCase: ExportVideoUseCase
    let mockRepository: MockProjectRepository
    let mockVideoExporter: MockVideoExporter

    init() async throws {
        mockRepository = MockProjectRepository()
        mockVideoExporter = MockVideoExporter()
        useCase = ExportVideoUseCase(repository: mockRepository, videoExporter: mockVideoExporter)
    }

    @Test("プロジェクトから書き出しURLを取得できる")
    func exportVideo() async throws {
        let project = Project(
            name: "テスト用Vlog",
            template: Template(segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング")
            ]),
            videoAssets: [
                VideoAsset(segmentOrder: 0, localFileURL: "mock://video.mp4", duration: 5)
            ]
        )
        try await mockRepository.save(project)

        let url = try await useCase.execute(
            project: project,
            bgmTrack: nil,
            bgmVolume: 0.3,
            progressHandler: { _ in }
        )

        #expect(!url.absoluteString.isEmpty)
        #expect(mockVideoExporter.exportCallCount == 1)
        #expect(mockVideoExporter.lastVideoAssetsCount == 1)
    }

    @Test("進捗ハンドラが呼ばれる")
    func progressHandlerIsCalled() async throws {
        let project = Project(
            name: "テスト用Vlog",
            template: Template(segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング")
            ]),
            videoAssets: [
                VideoAsset(segmentOrder: 0, localFileURL: "mock://video.mp4", duration: 5)
            ]
        )
        try await mockRepository.save(project)

        var progressCalled = false
        let url = try await useCase.execute(
            project: project,
            bgmTrack: nil,
            bgmVolume: 0.3,
            progressHandler: { progress in
                progressCalled = true
                #expect(progress >= 0.0 && progress <= 1.0)
            }
        )

        // MockVideoExporterの進捗はsendableハンドラ経由で非同期呼び出しされるため、
        // 少し待機してMainActorのタスクが実行されるようにする
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(progressCalled)
        #expect(!url.absoluteString.isEmpty)
    }

    @Test("セグメント順にvideoAssetsを結合する")
    func combineVideoAssetsInOrder() async throws {
        let project = Project(
            name: "テスト用Vlog",
            template: Template(segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング"),
                Segment(order: 1, startSeconds: 5, endSeconds: 10, segmentDescription: "メイン"),
                Segment(order: 2, startSeconds: 10, endSeconds: 15, segmentDescription: "エンディング")
            ]),
            videoAssets: [
                VideoAsset(segmentOrder: 0, localFileURL: "mock://video1.mp4", duration: 5),
                VideoAsset(segmentOrder: 1, localFileURL: "mock://video2.mp4", duration: 5),
                VideoAsset(segmentOrder: 2, localFileURL: "mock://video3.mp4", duration: 5)
            ]
        )
        try await mockRepository.save(project)

        let url = try await useCase.execute(
            project: project,
            bgmTrack: nil,
            bgmVolume: 0.3,
            progressHandler: { _ in }
        )

        #expect(!url.absoluteString.isEmpty)
        #expect(mockVideoExporter.lastVideoAssetsCount == 3)
        #expect(mockVideoExporter.lastSegmentsCount == 3)
    }

    @Test("すべてのSubtitleが含まれる")
    func includesAllSubtitles() async throws {
        let project = Project(
            name: "テスト用Vlog",
            template: Template(segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング"),
                Segment(order: 1, startSeconds: 5, endSeconds: 10, segmentDescription: "メイン")
            ]),
            videoAssets: [
                VideoAsset(segmentOrder: 0, localFileURL: "mock://video1.mp4", duration: 5),
                VideoAsset(segmentOrder: 1, localFileURL: "mock://video2.mp4", duration: 5)
            ],
            subtitles: [
                Subtitle(segmentOrder: 0, text: "オープニングです"),
                Subtitle(segmentOrder: 1, text: "メインです")
            ]
        )
        try await mockRepository.save(project)

        let url = try await useCase.execute(
            project: project,
            bgmTrack: nil,
            bgmVolume: 0.3,
            progressHandler: { _ in }
        )

        #expect(!url.absoluteString.isEmpty)
        #expect(mockVideoExporter.lastSubtitlesCount == 2)
    }

    @Test("BGMが設定されている場合は合成する")
    func exportWithBGM() async throws {
        let project = Project(
            name: "テスト用Vlog",
            template: Template(segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング")
            ]),
            videoAssets: [
                VideoAsset(segmentOrder: 0, localFileURL: "mock://video.mp4", duration: 5)
            ]
        )
        try await mockRepository.save(project)

        let bgmTrack = BGMTrack(
            id: "bgm-001",
            title: "爽やかな朝",
            description: "明るく前向きなVlogに最適",
            genre: "pop",
            duration: 120,
            storageUrl: "gs://bucket/bgm/morning.m4a",
            tags: ["明るい"]
        )

        let url = try await useCase.execute(
            project: project,
            bgmTrack: bgmTrack,
            bgmVolume: 0.3,
            progressHandler: { _ in }
        )

        #expect(!url.absoluteString.isEmpty)
        #expect(mockVideoExporter.lastBGMURL != nil)
        #expect(mockVideoExporter.lastBGMVolume == 0.3)
    }

    @Test("BGMなしでも書き出しできる")
    func exportWithoutBGM() async throws {
        let project = Project(
            name: "テスト用Vlog",
            template: Template(segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング")
            ]),
            videoAssets: [
                VideoAsset(segmentOrder: 0, localFileURL: "mock://video.mp4", duration: 5)
            ]
        )
        try await mockRepository.save(project)

        let url = try await useCase.execute(
            project: project,
            bgmTrack: nil,
            bgmVolume: 0.3,
            progressHandler: { _ in }
        )

        #expect(!url.absoluteString.isEmpty)
        #expect(mockVideoExporter.lastBGMURL == nil)
    }

    @Test("BGM音量が正しく適用される")
    func applyBGMVolume() async throws {
        let project = Project(
            name: "テスト用Vlog",
            template: Template(segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング")
            ]),
            videoAssets: [
                VideoAsset(segmentOrder: 0, localFileURL: "mock://video.mp4", duration: 5)
            ]
        )
        try await mockRepository.save(project)

        let bgmTrack = BGMTrack(
            id: "bgm-001",
            title: "爽やかな朝",
            description: "明るく前向きなVlogに最適",
            genre: "pop",
            duration: 120,
            storageUrl: "gs://bucket/bgm/morning.m4a",
            tags: ["明るい"]
        )

        // 音量0.1でテスト
        _ = try await useCase.execute(
            project: project,
            bgmTrack: bgmTrack,
            bgmVolume: 0.1,
            progressHandler: { _ in }
        )

        #expect(mockVideoExporter.lastBGMVolume == 0.1)

        // 音量1.0でテスト
        _ = try await useCase.execute(
            project: project,
            bgmTrack: bgmTrack,
            bgmVolume: 1.0,
            progressHandler: { _ in }
        )

        #expect(mockVideoExporter.lastBGMVolume == 1.0)
        #expect(mockVideoExporter.exportCallCount == 2)
    }

    @Test("videoAssetsが空の場合はエラー")
    func errorWhenNoVideoAssets() async throws {
        let project = Project(
            name: "テスト用Vlog",
            template: Template(segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング")
            ]),
            videoAssets: []
        )
        try await mockRepository.save(project)

        do {
            _ = try await useCase.execute(
                project: project,
                bgmTrack: nil,
                bgmVolume: 0.3,
                progressHandler: { _ in }
            )
            #expect(Bool(false), "エラーがthrowされるべき")
        } catch let error as ExportError {
            #expect(error == .noVideoAssets)
        } catch {
            #expect(Bool(false), "ExportErrorがthrowされるべき")
        }

        // エクスポーターは呼ばれないことを確認
        #expect(mockVideoExporter.exportCallCount == 0)
    }

    @Test("ストック動画（segmentOrder: nil）はフィルタされる")
    func filterStockVideoAssets() async throws {
        let project = Project(
            name: "テスト用Vlog",
            template: Template(segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング")
            ]),
            videoAssets: [
                VideoAsset(segmentOrder: 0, localFileURL: "mock://video.mp4", duration: 5),
                VideoAsset(segmentOrder: nil, localFileURL: "mock://stock.mp4", duration: 10)
            ]
        )
        try await mockRepository.save(project)

        let url = try await useCase.execute(
            project: project,
            bgmTrack: nil,
            bgmVolume: 0.3,
            progressHandler: { _ in }
        )

        #expect(!url.absoluteString.isEmpty)
        // ストック動画はフィルタされ、割り当て済みの1つだけが渡される
        #expect(mockVideoExporter.lastVideoAssetsCount == 1)
    }

    @Test("すべてのvideoAssetsがストックの場合はエラー")
    func errorWhenAllAssetsAreStock() async throws {
        let project = Project(
            name: "テスト用Vlog",
            template: Template(segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング")
            ]),
            videoAssets: [
                VideoAsset(segmentOrder: nil, localFileURL: "mock://stock1.mp4", duration: 5),
                VideoAsset(segmentOrder: nil, localFileURL: "mock://stock2.mp4", duration: 10)
            ]
        )
        try await mockRepository.save(project)

        do {
            _ = try await useCase.execute(
                project: project,
                bgmTrack: nil,
                bgmVolume: 0.3,
                progressHandler: { _ in }
            )
            #expect(Bool(false), "エラーがthrowされるべき")
        } catch let error as ExportError {
            #expect(error == .noVideoAssets)
        } catch {
            #expect(Bool(false), "ExportErrorがthrowされるべき")
        }
    }
}
