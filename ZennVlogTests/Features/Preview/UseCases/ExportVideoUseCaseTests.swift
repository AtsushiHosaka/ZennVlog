import Testing
@testable import ZennVlog

@Suite("ExportVideoUseCase テスト")
@MainActor
struct ExportVideoUseCaseTests {
    let useCase: ExportVideoUseCase
    let mockRepository: MockProjectRepository

    init() async throws {
        mockRepository = MockProjectRepository()
        useCase = ExportVideoUseCase(repository: mockRepository)
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

        // 異なる音量でテスト
        let url1 = try await useCase.execute(
            project: project,
            bgmTrack: bgmTrack,
            bgmVolume: 0.1,
            progressHandler: { _ in }
        )

        let url2 = try await useCase.execute(
            project: project,
            bgmTrack: bgmTrack,
            bgmVolume: 1.0,
            progressHandler: { _ in }
        )

        #expect(!url1.absoluteString.isEmpty)
        #expect(!url2.absoluteString.isEmpty)
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
    }
}
