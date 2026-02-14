import Foundation
import Testing
@testable import ZennVlog

private final class PreviewMockVideoExporter: VideoExporterProtocol, @unchecked Sendable {
    func export(
        videoAssets _: [VideoAsset],
        subtitles _: [Subtitle],
        segments _: [Segment],
        bgmURL _: URL?,
        bgmVolume _: Float,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        progressHandler(0.5)
        progressHandler(1.0)
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("preview_vm_mock.mp4")
    }
}

@Suite("PreviewViewModel Tests")
@MainActor
struct PreviewViewModelTests {

    private func createViewModel(project: Project? = nil) -> PreviewViewModel {
        let projectRepository = MockProjectRepository(emptyForTesting: true)
        let bgmRepository = MockBGMRepository()
        let exporter = PreviewMockVideoExporter()

        return PreviewViewModel(
            project: project ?? createProject(),
            exportVideoUseCase: ExportVideoUseCase(
                repository: projectRepository,
                videoExporter: exporter
            ),
            fetchBGMTracksUseCase: FetchBGMTracksUseCase(repository: bgmRepository),
            saveSubtitleUseCase: SaveSubtitleUseCase(repository: projectRepository),
            deleteSubtitleUseCase: DeleteSubtitleUseCase(repository: projectRepository),
            saveBGMSettingsUseCase: SaveBGMSettingsUseCase(repository: projectRepository),
            downloadBGMUseCase: DownloadBGMUseCase(repository: bgmRepository),
            updateSubtitlePositionUseCase: UpdateSubtitlePositionUseCase(repository: projectRepository)
        )
    }

    private func createProject() -> Project {
        Project(
            name: "テスト用Vlog",
            template: Template(
                segments: [
                    Segment(order: 0, startSeconds: 0, endSeconds: 10, segmentDescription: "オープニング"),
                    Segment(order: 1, startSeconds: 10, endSeconds: 25, segmentDescription: "メイン"),
                    Segment(order: 2, startSeconds: 25, endSeconds: 40, segmentDescription: "エンディング")
                ]
            ),
            videoAssets: [
                VideoAsset(segmentOrder: 0, localFileURL: "mock://v1.mp4", duration: 10),
                VideoAsset(segmentOrder: 1, localFileURL: "mock://v2.mp4", duration: 15),
                VideoAsset(segmentOrder: 2, localFileURL: "mock://v3.mp4", duration: 15)
            ],
            subtitles: [
                Subtitle(startSeconds: 0, endSeconds: 3, text: "start"),
                Subtitle(startSeconds: 12, endSeconds: 16, text: "middle"),
                Subtitle(startSeconds: 28, endSeconds: 31, text: "end")
            ],
            selectedBGMId: "bgm-001",
            bgmVolume: 0.65,
            status: .editing
        )
    }

    @Test("loadProjectでBGMとdurationと音量を復元する")
    func loadProjectRestoresState() async {
        let viewModel = createViewModel()

        await viewModel.loadProject()

        #expect(viewModel.duration == 40.0)
        #expect(viewModel.bgmTracks.count == 5)
        #expect(viewModel.selectedBGM?.id == "bgm-001")
        #expect(viewModel.bgmVolume == 0.65)
    }

    @Test("seekで現在時刻とセグメントが更新される")
    func seekUpdatesCurrentSegment() async {
        let viewModel = createViewModel()
        await viewModel.loadProject()

        viewModel.seek(to: 14)

        #expect(viewModel.currentTime == 14)
        #expect(viewModel.currentSegmentIndex == 1)
    }

    @Test("activeSubtitleが時刻一致するテロップを返す")
    func activeSubtitleMatchesTime() async {
        let viewModel = createViewModel()
        await viewModel.loadProject()

        let subtitle = viewModel.activeSubtitle(at: 12.5)
        #expect(subtitle?.text == "middle")
    }

    @Test("activeSubtitleが時間境界で正しく切り替わる")
    func activeSubtitleBoundarySwitching() async {
        let viewModel = createViewModel()
        await viewModel.loadProject()

        #expect(viewModel.activeSubtitle(at: 0.5)?.text == "start")
        #expect(viewModel.activeSubtitle(at: 3.3) == nil)
        #expect(viewModel.activeSubtitle(at: 13.5)?.text == "middle")
        #expect(viewModel.activeSubtitle(at: 28.5)?.text == "end")
    }

    @Test("新規テロップSheetを開ける")
    func openNewSubtitleSheet() async {
        let viewModel = createViewModel()
        await viewModel.loadProject()

        viewModel.showNewSubtitleSheet(at: 5)

        #expect(viewModel.subtitleSheetState != nil)
        #expect(viewModel.subtitleSheetState?.startSeconds == 5)
    }

    @Test("テロップを保存できる")
    func saveSubtitle() async {
        let viewModel = createViewModel()
        await viewModel.loadProject()

        let draft = SubtitleSheetState(
            startSeconds: 20,
            endSeconds: 22,
            text: "new subtitle"
        )
        let success = await viewModel.saveSubtitle(draft)

        #expect(success)
        #expect(viewModel.project.subtitles.contains { $0.text == "new subtitle" })
    }

    @Test("重複テロップ保存時は失敗する")
    func saveSubtitleRejectOverlap() async {
        let viewModel = createViewModel()
        await viewModel.loadProject()

        let draft = SubtitleSheetState(
            startSeconds: 1,
            endSeconds: 2,
            text: "overlap"
        )
        let success = await viewModel.saveSubtitle(draft)

        #expect(!success)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("BGM設定を保存できる")
    func saveBGMSettings() async {
        let viewModel = createViewModel()
        await viewModel.loadProject()
        let newTrack = viewModel.bgmTracks.first { $0.id == "bgm-002" }

        let success = await viewModel.saveBGMSettings(track: newTrack, volume: 0.2)

        #expect(success)
        #expect(viewModel.selectedBGM?.id == "bgm-002")
        #expect(viewModel.project.selectedBGMId == "bgm-002")
        #expect(viewModel.project.bgmVolume == 0.2)
    }

    @Test("書き出し成功時にURLを返す")
    func exportVideoReturnsURL() async {
        let viewModel = createViewModel()
        await viewModel.loadProject()

        let url = await viewModel.exportVideo()

        #expect(url != nil)
        #expect(viewModel.isExporting == false)
    }
}
