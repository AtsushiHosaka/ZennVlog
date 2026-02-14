import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class RecordingViewModel {

    // MARK: - Properties

    var project: Project
    var currentSegmentIndex: Int = 0
    var isRecording: Bool = false
    var recordingDuration: Double = 0.0
    var guideImage: UIImage?
    var isLoadingGuideImage: Bool = false
    var showGuideImage: Bool = false
    var errorMessage: String?
    var showTrimEditor: Bool = false
    var videoToTrim: URL?
    var videoScenes: [(timestamp: Double, description: String)] = []
    var isAnalyzingVideo: Bool = false
    var analysisProgress: Double = 0

    // MARK: - Computed Properties

    var segments: [Segment] {
        project.template?.segments.sorted { $0.order < $1.order } ?? []
    }

    var videoAssets: [VideoAsset] {
        project.videoAssets.filter { $0.segmentOrder != nil }
    }

    var stockVideoAssets: [VideoAsset] {
        project.videoAssets.filter { $0.segmentOrder == nil }
    }

    var currentSegment: Segment? {
        guard currentSegmentIndex >= 0 && currentSegmentIndex < segments.count else { return nil }
        return segments[currentSegmentIndex]
    }

    var canProceedToPreview: Bool {
        guard !segments.isEmpty else { return false }
        let recordedOrders = Set(videoAssets.compactMap { $0.segmentOrder })
        return segments.allSatisfy { recordedOrders.contains($0.order) }
    }

    var firstEmptySegmentOrder: Int? {
        let recordedOrders = Set(videoAssets.compactMap { $0.segmentOrder })
        return segments.first { !recordedOrders.contains($0.order) }?.order
    }

    // MARK: - Dependencies

    private let saveVideoAssetUseCase: SaveVideoAssetUseCase
    private let generateGuideImageUseCase: GenerateGuideImageUseCase
    private let analyzeVideoUseCase: AnalyzeVideoUseCase
    private let trimVideoUseCase: TrimVideoUseCase
    private let deleteVideoAssetUseCase: DeleteVideoAssetUseCase

    // MARK: - Private Properties

    private var guideImageCache: [Int: UIImage] = [:]
    private let maxCacheSize = 5

    // MARK: - Init

    init(
        project: Project,
        saveVideoAssetUseCase: SaveVideoAssetUseCase,
        generateGuideImageUseCase: GenerateGuideImageUseCase,
        analyzeVideoUseCase: AnalyzeVideoUseCase,
        trimVideoUseCase: TrimVideoUseCase,
        deleteVideoAssetUseCase: DeleteVideoAssetUseCase
    ) {
        self.project = project
        self.saveVideoAssetUseCase = saveVideoAssetUseCase
        self.generateGuideImageUseCase = generateGuideImageUseCase
        self.analyzeVideoUseCase = analyzeVideoUseCase
        self.trimVideoUseCase = trimVideoUseCase
        self.deleteVideoAssetUseCase = deleteVideoAssetUseCase
    }

    // MARK: - Public Methods

    func canRecord(for segmentOrder: Int) -> Bool {
        guard let firstEmpty = firstEmptySegmentOrder else {
            return false // 全て埋まっている
        }
        return segmentOrder == firstEmpty
    }

    func isSegmentRecorded(_ segmentOrder: Int) -> Bool {
        videoAssets.contains { $0.segmentOrder == segmentOrder }
    }

    func selectSegment(at index: Int) {
        guard index >= 0 && index < segments.count else { return }
        currentSegmentIndex = index

        // ガイド画像をロード
        Task {
            await loadGuideImage(for: segments[index])
        }
    }

    func startRecording() {
        guard let currentSegment,
              canRecord(for: currentSegment.order) else {
            return
        }

        isRecording = true
        recordingDuration = 0.0
    }

    func stopRecording() {
        isRecording = false
    }

    func saveRecordedVideo(localFileURL: String, duration: Double) async {
        guard let currentSegment else { return }

        do {
            let segmentOrder = canRecord(for: currentSegment.order) ? currentSegment.order : nil

            try await saveVideoAssetUseCase.execute(
                project: project,
                localFileURL: localFileURL,
                duration: duration,
                segmentOrder: segmentOrder
            )

            // 次の空白セグメントに移動
            if let nextEmpty = firstEmptySegmentOrder,
               let nextIndex = segments.firstIndex(where: { $0.order == nextEmpty }) {
                currentSegmentIndex = nextIndex
            }
        } catch {
            errorMessage = "動画の保存に失敗しました"
        }
    }

    func processSelectedVideo(url: URL) async {
        isAnalyzingVideo = true
        analysisProgress = 0

        let progressObserver = NotificationCenter.default.addObserver(
            forName: .videoAnalysisProgressDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard self.isAnalyzingVideo else { return }

            let progress = notification.userInfo?[VideoAnalysisProgressUserInfoKey.progress] as? Double ?? 0
            self.analysisProgress = min(max(progress, 0), 1)
        }

        defer {
            NotificationCenter.default.removeObserver(progressObserver)
            isAnalyzingVideo = false
            if analysisProgress >= 1 {
                analysisProgress = 1
            } else {
                analysisProgress = 0
            }
        }

        do {
            // 動画を分析
            let result = try await analyzeVideoUseCase.execute(videoURL: url)

            // シーン情報を設定
            videoScenes = result.segments.map { segment in
                (timestamp: segment.startSeconds, description: segment.description)
            }

            // トリムエディタを表示
            videoToTrim = url
            showTrimEditor = true
            analysisProgress = 1
        } catch {
            errorMessage = "動画の分析に失敗しました"
        }
    }

    func trimAndSaveVideo(startSeconds: Double, for segmentOrder: Int) async {
        guard let videoURL = videoToTrim,
              let segment = segments.first(where: { $0.order == segmentOrder }) else {
            return
        }

        let segmentDuration = segment.endSeconds - segment.startSeconds

        do {
            let trimmedURL = try await trimVideoUseCase.execute(
                videoURL: videoURL,
                startSeconds: startSeconds,
                duration: segmentDuration
            )

            try await saveVideoAssetUseCase.execute(
                project: project,
                localFileURL: trimmedURL.path,
                duration: segmentDuration,
                segmentOrder: segmentOrder,
                trimStartSeconds: startSeconds
            )

            showTrimEditor = false
            videoToTrim = nil
            videoScenes = []
        } catch {
            errorMessage = "動画のトリムに失敗しました"
        }
    }

    func deleteVideoAsset(for segmentOrder: Int) async {
        do {
            try await deleteVideoAssetUseCase.execute(
                project: project,
                segmentOrder: segmentOrder
            )
        } catch {
            errorMessage = "動画の削除に失敗しました"
        }
    }

    func deleteStockAsset(_ asset: VideoAsset) async {
        do {
            try await deleteVideoAssetUseCase.execute(
                project: project,
                videoAssetId: asset.id
            )
        } catch {
            errorMessage = "動画の削除に失敗しました"
        }
    }

    func assignStockToSegment(_ asset: VideoAsset, segmentOrder: Int) async {
        guard let segment = segments.first(where: { $0.order == segmentOrder }) else {
            return
        }

        do {
            // ストックから削除
            try await deleteVideoAssetUseCase.execute(
                project: project,
                videoAssetId: asset.id
            )

            // セグメントに割り当て
            let segmentDuration = segment.endSeconds - segment.startSeconds
            try await saveVideoAssetUseCase.execute(
                project: project,
                localFileURL: asset.localFileURL,
                duration: segmentDuration,
                segmentOrder: segmentOrder,
                trimStartSeconds: asset.trimStartSeconds
            )
        } catch {
            errorMessage = "動画の割り当てに失敗しました"
        }
    }

    func toggleGuideImage() {
        showGuideImage.toggle()

        if showGuideImage, guideImage == nil, let currentSegment {
            Task {
                await loadGuideImage(for: currentSegment)
            }
        }
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Private Methods

    private func loadGuideImage(for segment: Segment) async {
        // キャッシュから取得
        if let cachedImage = guideImageCache[segment.order] {
            guideImage = cachedImage
            return
        }

        guard !segment.segmentDescription.isEmpty else { return }

        isLoadingGuideImage = true

        do {
            let image = try await generateGuideImageUseCase.execute(
                prompt: segment.segmentDescription
            )

            // キャッシュに保存（最大5個）
            if guideImageCache.count >= maxCacheSize {
                guideImageCache.removeValue(forKey: guideImageCache.keys.min() ?? 0)
            }
            guideImageCache[segment.order] = image

            guideImage = image
        } catch {
            errorMessage = "ガイド画像の生成に失敗しました"
        }

        isLoadingGuideImage = false
    }

    func segmentWidth(for segment: Segment, totalWidth: CGFloat) -> CGFloat {
        let totalDuration = segments.reduce(0.0) { total, seg in
            total + (seg.endSeconds - seg.startSeconds)
        }
        guard totalDuration > 0 else { return 0 }

        let segmentDuration = segment.endSeconds - segment.startSeconds
        return totalWidth * CGFloat(segmentDuration / totalDuration)
    }
}
