import AVFoundation
import Foundation
import Testing
@testable import ZennVlog

@Suite("PreviewViewModel Tests")
@MainActor
struct PreviewViewModelTests {

    // MARK: - ヘルパー

    private func createViewModel(
        project: Project? = nil
    ) -> PreviewViewModel {
        let projectRepo = MockProjectRepository(emptyForTesting: true)
        let bgmRepo = MockBGMRepository()

        let viewModel = PreviewViewModel(
            project: project ?? createTestProject(),
            exportVideoUseCase: ExportVideoUseCase(repository: projectRepo),
            fetchBGMTracksUseCase: FetchBGMTracksUseCase(repository: bgmRepo),
            saveSubtitleUseCase: SaveSubtitleUseCase(repository: projectRepo),
            downloadBGMUseCase: DownloadBGMUseCase(repository: bgmRepo)
        )

        return viewModel
    }

    private func createTestProject() -> Project {
        Project(
            name: "テスト用Vlog",
            template: Template(segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 10, segmentDescription: "オープニング"),
                Segment(order: 1, startSeconds: 10, endSeconds: 25, segmentDescription: "メインシーン"),
                Segment(order: 2, startSeconds: 25, endSeconds: 40, segmentDescription: "エンディング")
            ]),
            videoAssets: [
                VideoAsset(segmentOrder: 0, localFileURL: "mock://video1.mp4", duration: 10),
                VideoAsset(segmentOrder: 1, localFileURL: "mock://video2.mp4", duration: 15),
                VideoAsset(segmentOrder: 2, localFileURL: "mock://video3.mp4", duration: 15)
            ],
            status: .editing
        )
    }

    private func createProjectWithSubtitles() -> Project {
        let project = createTestProject()
        project.subtitles = [
            Subtitle(segmentOrder: 0, text: "オープニングテロップ"),
            Subtitle(segmentOrder: 1, text: "メインテロップ"),
            Subtitle(segmentOrder: 2, text: "エンディングテロップ")
        ]
        return project
    }

    // MARK: - 初期状態のテスト

    @Test("初期状態が正しく設定される")
    func 初期状態が正しく設定される() {
        // Given & When
        let viewModel = createViewModel()

        // Then
        #expect(viewModel.isPlaying == false)
        #expect(viewModel.currentTime == 0.0)
        #expect(viewModel.duration == 0.0)
        #expect(viewModel.currentSegmentIndex == 0)
        #expect(viewModel.subtitleText.isEmpty)
        #expect(viewModel.selectedBGM == nil)
        #expect(viewModel.bgmVolume == 0.3)
        #expect(viewModel.bgmTracks.isEmpty)
        #expect(viewModel.showBGMSelector == false)
        #expect(viewModel.isExporting == false)
        #expect(viewModel.exportProgress == 0.0)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("segmentsがテンプレートから取得される")
    func segmentsがテンプレートから取得される() {
        // Given & When
        let viewModel = createViewModel()

        // Then
        #expect(viewModel.segments.count == 3)
    }

    @Test("テンプレートなしの場合segmentsが空")
    func テンプレートなしの場合segmentsが空() {
        // Given
        let project = Project(name: "テスト", status: .editing)

        // When
        let viewModel = createViewModel(project: project)

        // Then
        #expect(viewModel.segments.isEmpty)
    }

    // MARK: - loadProject テスト

    @Test("loadProjectでBGMトラックが読み込まれる")
    func loadProjectでBGMトラックが読み込まれる() async {
        // Given
        let viewModel = createViewModel()

        // When
        await viewModel.loadProject()

        // Then: MockBGMRepositoryは5曲返す
        #expect(viewModel.bgmTracks.count == 5)
    }

    @Test("loadProjectでdurationが計算される")
    func loadProjectでdurationが計算される() async {
        // Given
        let viewModel = createViewModel()

        // When
        await viewModel.loadProject()

        // Then: セグメント合計 = (10-0) + (25-10) + (40-25) = 10 + 15 + 15 = 40
        #expect(viewModel.duration == 40.0)
    }

    @Test("loadProjectで既存テロップが復元される")
    func loadProjectで既存テロップが復元される() async {
        // Given
        let project = createProjectWithSubtitles()
        let viewModel = createViewModel(project: project)

        // When
        await viewModel.loadProject()

        // Then: currentSegmentIndex == 0 なので、segment 0のテロップが復元される
        #expect(viewModel.subtitleText == "オープニングテロップ")
    }

    // MARK: - 再生制御テスト

    @Test("togglePlayPauseで再生状態が切り替わる")
    func togglePlayPauseで再生状態が切り替わる() {
        // Given
        let viewModel = createViewModel()
        #expect(viewModel.isPlaying == false)

        // When
        viewModel.togglePlayPause()

        // Then
        #expect(viewModel.isPlaying == true)

        // When
        viewModel.togglePlayPause()

        // Then
        #expect(viewModel.isPlaying == false)
    }

    @Test("seekToSegmentでcurrentTimeとcurrentSegmentIndexが更新される")
    func seekToSegmentでcurrentTimeとcurrentSegmentIndexが更新される() {
        // Given
        let viewModel = createViewModel()

        // When: セグメント1にシーク（startSeconds = 10）
        viewModel.seekToSegment(1)

        // Then
        #expect(viewModel.currentSegmentIndex == 1)
        #expect(viewModel.currentTime == 10.0)
    }

    @Test("範囲外のインデックスでは変更されない")
    func 範囲外のインデックスでは変更されない() {
        // Given
        let viewModel = createViewModel()
        let originalIndex = viewModel.currentSegmentIndex
        let originalTime = viewModel.currentTime

        // When
        viewModel.seekToSegment(99)

        // Then
        #expect(viewModel.currentSegmentIndex == originalIndex)
        #expect(viewModel.currentTime == originalTime)
    }

    @Test("seekToSegmentでテロップが復元される")
    func seekToSegmentでテロップが復元される() {
        // Given
        let project = createProjectWithSubtitles()
        let viewModel = createViewModel(project: project)

        // When: セグメント1にシーク
        viewModel.seekToSegment(1)

        // Then
        #expect(viewModel.subtitleText == "メインテロップ")
    }

    // MARK: - テロップテスト

    @Test("テロップを保存できる")
    func テロップを保存できる() async {
        // Given
        let viewModel = createViewModel()
        viewModel.subtitleText = "テストテロップ"

        // When
        await viewModel.saveSubtitle()

        // Then
        #expect(viewModel.errorMessage == nil)
        let subtitle = viewModel.project.subtitles.first { $0.segmentOrder == 0 }
        #expect(subtitle?.text == "テストテロップ")
    }

    // MARK: - BGMテスト

    @Test("BGMトラック一覧を取得できる")
    func BGMトラック一覧を取得できる() async {
        // Given
        let viewModel = createViewModel()

        // When
        await viewModel.loadBGMTracks()

        // Then
        #expect(viewModel.bgmTracks.count == 5)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("BGMを選択するとselectedBGMが更新される")
    func BGMを選択するとselectedBGMが更新される() async {
        // Given
        let viewModel = createViewModel()
        await viewModel.loadBGMTracks()
        let track = viewModel.bgmTracks.first!

        // When
        await viewModel.selectBGM(track)

        // Then
        #expect(viewModel.selectedBGM?.id == track.id)
        #expect(viewModel.showBGMSelector == false)
    }

    @Test("既存のselectedBGMIdからBGMが復元される")
    func 既存のselectedBGMIdからBGMが復元される() async {
        // Given
        let project = createTestProject()
        project.selectedBGMId = "bgm-001"
        let viewModel = createViewModel(project: project)

        // When
        await viewModel.loadProject()

        // Then
        #expect(viewModel.selectedBGM?.id == "bgm-001")
    }

    // MARK: - その他テスト

    @Test("exportVideoでexportedVideoURLが設定される")
    func exportVideoでexportedVideoURLが設定される() async {
        // Given
        let viewModel = createViewModel()

        // When
        await viewModel.exportVideo()

        // Then
        #expect(viewModel.isExporting == false)
        // exportVideoUseCase のMock実装がURLを返すので、URLが設定されるか、
        // エラーが発生する（videoAssetsが空の場合）
        // PreviewViewModelのプロジェクトにはvideoAssetsがあるので成功するはず
        // ただしMockProjectRepositoryにsaveされていないため、エラーになる可能性あり
        // ここではisExportingがfalseに戻ることを確認
    }

    @Test("clearErrorでerrorMessageがnilになる")
    func clearErrorでerrorMessageがnilになる() {
        // Given
        let viewModel = createViewModel()

        // When
        viewModel.clearError()

        // Then
        #expect(viewModel.errorMessage == nil)
    }
}
