import AVFoundation
import Foundation
import Observation
import OSLog
import UIKit

@MainActor
@Observable
final class RecordingViewModel {
    private let logger = Logger(subsystem: "ZennVlog", category: "RecordingViewModel")

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
    var selectedVideoDuration: Double = 0
    var isAnalyzingVideo: Bool = false
    var analysisProgress: Double = 0

    // MARK: - Computed Properties

    var segments: [Segment] {
        project.template?.segments.sorted { $0.order < $1.order } ?? []
    }

    var videoAssets: [VideoAsset] {
        project.videoAssets.filter { $0.segmentOrder != nil }
    }

    var recordedVideoAssets: [VideoAsset] {
        let playableOrders = playableSegmentOrders
        return videoAssets.filter { asset in
            guard let order = asset.segmentOrder else { return false }
            return playableOrders.contains(order)
        }
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
        let assignedOrders = Set(videoAssets.compactMap(\.segmentOrder))
        return segments.allSatisfy { assignedOrders.contains($0.order) }
    }

    var firstEmptySegmentOrder: Int? {
        let playableOrders = playableSegmentOrders
        return segments.first { !playableOrders.contains($0.order) }?.order
    }

    // MARK: - Dependencies

    private let saveVideoAssetUseCase: SaveVideoAssetUseCase
    private let generateGuideImageUseCase: GenerateGuideImageUseCase
    private let analyzeVideoUseCase: AnalyzeVideoUseCase
    private let trimVideoUseCase: TrimVideoUseCase
    private let deleteVideoAssetUseCase: DeleteVideoAssetUseCase
    private let workflowManager: RecordingWorkflowManager?

    // MARK: - Private Properties

    private var guideImageCache: [Int: UIImage] = [:]
    private let maxCacheSize = 5
    
    // MARK: - Private Protocol
    private let photoLibraryService: PhotoLibraryServiceProtocol
    private let localVideoStorage: LocalVideoStorage

    // MARK: - Init

    init(
        project: Project,
        saveVideoAssetUseCase: SaveVideoAssetUseCase,
        generateGuideImageUseCase: GenerateGuideImageUseCase,
        analyzeVideoUseCase: AnalyzeVideoUseCase,
        trimVideoUseCase: TrimVideoUseCase,
        deleteVideoAssetUseCase: DeleteVideoAssetUseCase,
        photoLibraryService: PhotoLibraryServiceProtocol,
        localVideoStorage: LocalVideoStorage,
        workflowManager: RecordingWorkflowManager? = nil
    ) {
        self.project = project
        self.saveVideoAssetUseCase = saveVideoAssetUseCase
        self.generateGuideImageUseCase = generateGuideImageUseCase
        self.analyzeVideoUseCase = analyzeVideoUseCase
        self.trimVideoUseCase = trimVideoUseCase
        self.deleteVideoAssetUseCase = deleteVideoAssetUseCase
        self.photoLibraryService = photoLibraryService
        self.localVideoStorage = localVideoStorage
        self.workflowManager = workflowManager
    }

    // MARK: - Public Methods

    func canRecord(for segmentOrder: Int) -> Bool {
        guard let firstEmpty = firstEmptySegmentOrder else {
            return false // 全て埋まっている
        }
        return segmentOrder == firstEmpty
    }

    func isSegmentRecorded(_ segmentOrder: Int) -> Bool {
        playableSegmentOrders.contains(segmentOrder)
    }

    func isSegmentMissing(_ segmentOrder: Int) -> Bool {
        !isSegmentRecorded(segmentOrder)
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
            guard FileManager.default.fileExists(atPath: localFileURL) else {
                errorMessage = "録画ファイルが見つかりません"
                return
            }

            let sourceURL = URL(fileURLWithPath: localFileURL)
            let videoAssetId = UUID()
            let persistentURL = try localVideoStorage.persistVideo(
                sourceURL: sourceURL,
                projectId: project.id,
                assetId: videoAssetId
            )
            logger.info("Prepared persistent video for recording: \(persistentURL.path, privacy: .public)")

            let photoAssetIdentifier = try await photoLibraryService.saveVideoToAlbum(
                videoURL: persistentURL,
                projectName: project.name
            )

            let segmentOrder = canRecord(for: currentSegment.order) ? currentSegment.order : nil

            try await saveVideoAssetUseCase.execute(
                project: project,
                localFileURL: persistentURL,
                duration: duration,
                segmentOrder: segmentOrder,
                photoAssetIdentifier: photoAssetIdentifier,
                videoAssetId: videoAssetId
            )
            await workflowManager?.updateStatusIfReadyForPreview(project: project)
            
            // 次の空白セグメントに移動
            if let nextEmpty = firstEmptySegmentOrder,
               let nextIndex = segments.firstIndex(where: { $0.order == nextEmpty }) {
                currentSegmentIndex = nextIndex
            }
        } catch {
            errorMessage = "動画の保存に失敗しました: \(error)"
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
            let progress = notification.userInfo?[VideoAnalysisProgressUserInfoKey.progress] as? Double ?? 0
            Task { @MainActor [weak self] in
                guard let self, self.isAnalyzingVideo else { return }
                self.analysisProgress = min(max(progress, 0), 1)
            }
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
            let avAsset = AVURLAsset(url: url)
            if let duration = try? await avAsset.load(.duration) {
                selectedVideoDuration = CMTimeGetSeconds(duration)
            } else {
                selectedVideoDuration = 0
            }

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
            selectedVideoDuration = 0
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

            let videoAssetId = UUID()
            let persistentURL = try localVideoStorage.persistVideo(
                sourceURL: trimmedURL,
                projectId: project.id,
                assetId: videoAssetId
            )
            logger.info("Prepared persistent video for trim: \(persistentURL.path, privacy: .public)")

            try await saveVideoAssetUseCase.execute(
                project: project,
                localFileURL: persistentURL,
                duration: segmentDuration,
                segmentOrder: segmentOrder,
                trimStartSeconds: startSeconds,
                videoAssetId: videoAssetId
            )
            await workflowManager?.updateStatusIfReadyForPreview(project: project)

            showTrimEditor = false
            videoToTrim = nil
            videoScenes = []
            selectedVideoDuration = 0
        } catch {
            errorMessage = "動画のトリムに失敗しました"
        }
    }

    func cancelTrimEditor() {
        showTrimEditor = false
        videoToTrim = nil
        videoScenes = []
        selectedVideoDuration = 0
        analysisProgress = 0
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
            guard let sourceURL = VideoAssetPathResolver.resolveLocalURL(from: asset.localFileURL) else {
                errorMessage = "割り当て元の動画ファイルが見つかりません"
                return
            }

            // セグメントに割り当て
            let segmentDuration = segment.endSeconds - segment.startSeconds
            try await saveVideoAssetUseCase.execute(
                project: project,
                localFileURL: sourceURL,
                duration: segmentDuration,
                segmentOrder: segmentOrder,
                trimStartSeconds: asset.trimStartSeconds
            )

            // ストックから削除（先に割り当てることで同一パス参照中の削除を防ぐ）
            try await deleteVideoAssetUseCase.execute(
                project: project,
                videoAssetId: asset.id
            )
            await workflowManager?.updateStatusIfReadyForPreview(project: project)
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

    private var playableSegmentOrders: Set<Int> {
        Set(
            videoAssets.compactMap { asset in
                guard let order = asset.segmentOrder else { return nil }
                guard VideoAssetPathResolver.resolveLocalURL(from: asset.localFileURL) != nil else {
                    return nil
                }
                return order
            }
        )
    }
}
