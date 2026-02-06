import Foundation
import Testing
import UIKit
@testable import ZennVlog

@Suite("RecordingViewModel Tests")
@MainActor
struct RecordingViewModelTests {

    // MARK: - ヘルパー

    private func createViewModel(
        project: Project? = nil
    ) -> RecordingViewModel {
        let projectRepo = MockProjectRepository(emptyForTesting: true)
        let imagenRepo = MockImagenRepository()
        let geminiRepo = MockGeminiRepository()

        let viewModel = RecordingViewModel(
            project: project ?? createTestProject(),
            saveVideoAssetUseCase: SaveVideoAssetUseCase(repository: projectRepo),
            generateGuideImageUseCase: GenerateGuideImageUseCase(repository: imagenRepo),
            analyzeVideoUseCase: AnalyzeVideoUseCase(repository: geminiRepo),
            trimVideoUseCase: TrimVideoUseCase(),
            deleteVideoAssetUseCase: DeleteVideoAssetUseCase(repository: projectRepo)
        )

        return viewModel
    }

    private func createTestProject() -> Project {
        Project(
            name: "テスト用Vlog",
            template: Template(segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング"),
                Segment(order: 1, startSeconds: 5, endSeconds: 15, segmentDescription: "メインシーン"),
                Segment(order: 2, startSeconds: 15, endSeconds: 25, segmentDescription: "エンディング")
            ]),
            videoAssets: [],
            status: .recording
        )
    }

    private func createProjectWithAssets() -> Project {
        Project(
            name: "テスト用Vlog",
            template: Template(segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング"),
                Segment(order: 1, startSeconds: 5, endSeconds: 15, segmentDescription: "メインシーン"),
                Segment(order: 2, startSeconds: 15, endSeconds: 25, segmentDescription: "エンディング")
            ]),
            videoAssets: [
                VideoAsset(segmentOrder: 0, localFileURL: "mock://video1.mp4", duration: 5),
                VideoAsset(segmentOrder: 1, localFileURL: "mock://video2.mp4", duration: 10)
            ],
            status: .recording
        )
    }

    private func createFullProject() -> Project {
        Project(
            name: "テスト用Vlog",
            template: Template(segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング"),
                Segment(order: 1, startSeconds: 5, endSeconds: 15, segmentDescription: "メインシーン"),
                Segment(order: 2, startSeconds: 15, endSeconds: 25, segmentDescription: "エンディング")
            ]),
            videoAssets: [
                VideoAsset(segmentOrder: 0, localFileURL: "mock://video1.mp4", duration: 5),
                VideoAsset(segmentOrder: 1, localFileURL: "mock://video2.mp4", duration: 10),
                VideoAsset(segmentOrder: 2, localFileURL: "mock://video3.mp4", duration: 10)
            ],
            status: .recording
        )
    }

    // MARK: - 初期状態のテスト

    @Test("初期状態が正しく設定される")
    func 初期状態が正しく設定される() {
        // Given & When
        let viewModel = createViewModel()

        // Then
        #expect(viewModel.segments.count == 3)
        #expect(viewModel.videoAssets.isEmpty)
        #expect(viewModel.stockVideoAssets.isEmpty)
        #expect(viewModel.isRecording == false)
        #expect(viewModel.recordingDuration == 0.0)
        #expect(viewModel.canProceedToPreview == false)
        #expect(viewModel.currentSegmentIndex == 0)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.guideImage == nil)
        #expect(viewModel.showGuideImage == false)
        #expect(viewModel.showTrimEditor == false)
    }

    @Test("テンプレートがないプロジェクトではsegmentsが空")
    func テンプレートがないプロジェクトではsegmentsが空() {
        // Given
        let project = Project(name: "テスト", status: .recording)

        // When
        let viewModel = createViewModel(project: project)

        // Then
        #expect(viewModel.segments.isEmpty)
    }

    // MARK: - computed properties テスト

    @Test("videoAssetsがsegmentOrder非nilのみ含む")
    func videoAssetsがsegmentOrder非nilのみ含む() {
        // Given
        let project = Project(
            name: "テスト",
            template: Template(segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "テスト")
            ]),
            videoAssets: [
                VideoAsset(segmentOrder: 0, localFileURL: "mock://v1.mp4", duration: 5),
                VideoAsset(segmentOrder: nil, localFileURL: "mock://stock.mp4", duration: 10)
            ]
        )

        // When
        let viewModel = createViewModel(project: project)

        // Then
        #expect(viewModel.videoAssets.count == 1)
        #expect(viewModel.videoAssets.first?.segmentOrder == 0)
    }

    @Test("stockVideoAssetsがsegmentOrder nilのみ含む")
    func stockVideoAssetsがsegmentOrder_nilのみ含む() {
        // Given
        let project = Project(
            name: "テスト",
            template: Template(segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "テスト")
            ]),
            videoAssets: [
                VideoAsset(segmentOrder: 0, localFileURL: "mock://v1.mp4", duration: 5),
                VideoAsset(segmentOrder: nil, localFileURL: "mock://stock.mp4", duration: 10)
            ]
        )

        // When
        let viewModel = createViewModel(project: project)

        // Then
        #expect(viewModel.stockVideoAssets.count == 1)
        #expect(viewModel.stockVideoAssets.first?.segmentOrder == nil)
    }

    // MARK: - canProceedToPreview テスト

    @Test("全セグメントに動画があればcanProceedToPreviewがtrue")
    func 全セグメントに動画があればcanProceedToPreviewがtrue() {
        // Given & When
        let viewModel = createViewModel(project: createFullProject())

        // Then
        #expect(viewModel.canProceedToPreview == true)
    }

    @Test("一部欠けていればcanProceedToPreviewがfalse")
    func 一部欠けていればcanProceedToPreviewがfalse() {
        // Given & When
        let viewModel = createViewModel(project: createProjectWithAssets())

        // Then
        #expect(viewModel.canProceedToPreview == false)
    }

    @Test("segmentsが空の場合canProceedToPreviewがfalse")
    func segmentsが空の場合canProceedToPreviewがfalse() {
        // Given
        let project = Project(name: "テスト", status: .recording)

        // When
        let viewModel = createViewModel(project: project)

        // Then
        #expect(viewModel.canProceedToPreview == false)
    }

    // MARK: - canRecord / firstEmptySegmentOrder テスト

    @Test("最初の空白セグメントで撮影可能")
    func 最初の空白セグメントで撮影可能() {
        // Given & When
        let viewModel = createViewModel()

        // Then: 全て空白なので最初のセグメント(0)で撮影可能
        #expect(viewModel.canRecord(for: 0) == true)
        #expect(viewModel.canRecord(for: 1) == false)
        #expect(viewModel.canRecord(for: 2) == false)
    }

    @Test("最初が埋まっている場合は2番目で撮影可能")
    func 最初が埋まっている場合は2番目で撮影可能() {
        // Given
        let viewModel = createViewModel(project: createProjectWithAssets())

        // Then: order 0, 1 が埋まっているので order 2 のみ可能
        #expect(viewModel.canRecord(for: 0) == false)
        #expect(viewModel.canRecord(for: 1) == false)
        #expect(viewModel.canRecord(for: 2) == true)
    }

    @Test("全て埋まっている場合は撮影不可")
    func 全て埋まっている場合は撮影不可() {
        // Given
        let viewModel = createViewModel(project: createFullProject())

        // Then
        #expect(viewModel.canRecord(for: 0) == false)
        #expect(viewModel.canRecord(for: 1) == false)
        #expect(viewModel.canRecord(for: 2) == false)
    }

    @Test("firstEmptySegmentOrderが正しい値を返す")
    func firstEmptySegmentOrderが正しい値を返す() {
        // Given: order 0, 1 が埋まっている
        let viewModel = createViewModel(project: createProjectWithAssets())

        // Then
        #expect(viewModel.firstEmptySegmentOrder == 2)
    }

    // MARK: - isSegmentRecorded テスト

    @Test("撮影済みセグメントでtrueを返す")
    func 撮影済みセグメントでtrueを返す() {
        // Given
        let viewModel = createViewModel(project: createProjectWithAssets())

        // Then
        #expect(viewModel.isSegmentRecorded(0) == true)
        #expect(viewModel.isSegmentRecorded(1) == true)
    }

    @Test("未撮影セグメントでfalseを返す")
    func 未撮影セグメントでfalseを返す() {
        // Given
        let viewModel = createViewModel(project: createProjectWithAssets())

        // Then
        #expect(viewModel.isSegmentRecorded(2) == false)
    }

    // MARK: - selectSegment テスト

    @Test("セグメントを選択するとcurrentSegmentIndexが更新される")
    func セグメントを選択するとcurrentSegmentIndexが更新される() {
        // Given
        let viewModel = createViewModel()
        #expect(viewModel.currentSegmentIndex == 0)

        // When
        viewModel.selectSegment(at: 2)

        // Then
        #expect(viewModel.currentSegmentIndex == 2)
    }

    @Test("範囲外のインデックスでは変更されない")
    func 範囲外のインデックスでは変更されない() {
        // Given
        let viewModel = createViewModel()
        #expect(viewModel.currentSegmentIndex == 0)

        // When
        viewModel.selectSegment(at: 99)

        // Then
        #expect(viewModel.currentSegmentIndex == 0)
    }

    // MARK: - startRecording / stopRecording テスト

    @Test("startRecordingでisRecordingがtrueになる")
    func startRecordingでisRecordingがtrueになる() {
        // Given: currentSegment(index 0) が最初の空白セグメント
        let viewModel = createViewModel()

        // When
        viewModel.startRecording()

        // Then
        #expect(viewModel.isRecording == true)
        #expect(viewModel.recordingDuration == 0.0)
    }

    @Test("撮影不可セグメントではstartRecordingが無視される")
    func 撮影不可セグメントではstartRecordingが無視される() {
        // Given: order 0, 1 が埋まっている
        let viewModel = createViewModel(project: createProjectWithAssets())
        // currentSegmentIndex = 0 だが、order 0 は埋まっているので撮影不可

        // When
        viewModel.startRecording()

        // Then
        #expect(viewModel.isRecording == false)
    }

    @Test("stopRecordingでisRecordingがfalseになる")
    func stopRecordingでisRecordingがfalseになる() {
        // Given
        let viewModel = createViewModel()
        viewModel.startRecording()
        #expect(viewModel.isRecording == true)

        // When
        viewModel.stopRecording()

        // Then
        #expect(viewModel.isRecording == false)
    }

    // MARK: - toggleGuideImage / clearError テスト

    @Test("toggleGuideImageでshowGuideImageが切り替わる")
    func toggleGuideImageでshowGuideImageが切り替わる() {
        // Given
        let viewModel = createViewModel()
        #expect(viewModel.showGuideImage == false)

        // When
        viewModel.toggleGuideImage()

        // Then
        #expect(viewModel.showGuideImage == true)

        // When
        viewModel.toggleGuideImage()

        // Then
        #expect(viewModel.showGuideImage == false)
    }

    @Test("clearErrorでerrorMessageがnilになる")
    func clearErrorでerrorMessageがnilになる() {
        // Given
        let viewModel = createViewModel()
        // errorMessageを直接設定（テスト用）
        // RecordingViewModelのerrorMessageは@Publishedなので直接設定可能

        // When
        viewModel.clearError()

        // Then
        #expect(viewModel.errorMessage == nil)
    }
}
