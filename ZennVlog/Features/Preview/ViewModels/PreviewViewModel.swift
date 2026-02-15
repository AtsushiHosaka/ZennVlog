import AVFoundation
import Foundation
import Observation
import OSLog

struct SubtitleSheetState: Identifiable, Equatable {
    let id: Int
    let segmentOrder: Int
    let subtitleId: UUID?
    let startSeconds: Double
    let endSeconds: Double
    var text: String

    init(
        segmentOrder: Int,
        subtitleId: UUID? = nil,
        startSeconds: Double,
        endSeconds: Double,
        text: String
    ) {
        self.segmentOrder = segmentOrder
        self.subtitleId = subtitleId
        self.id = segmentOrder
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.text = text
    }
}

struct SegmentTimelineItem: Identifiable, Equatable {
    let id: Int
    let segmentOrder: Int
    let startSeconds: Double
    let endSeconds: Double
    let videoLocalFileURL: String?
    let subtitleId: UUID?
    let subtitleText: String?

    var duration: Double {
        max(0, endSeconds - startSeconds)
    }

    var hasSubtitle: Bool {
        guard let subtitleText else { return false }
        return !subtitleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

@MainActor
@Observable
final class PreviewViewModel {
    private let logger = Logger(subsystem: "ZennVlog", category: "PreviewViewModel")

    // MARK: - State

    var project: Project
    var isPlaying: Bool = false
    var currentTime: Double = 0
    var duration: Double = 0
    var currentSegmentIndex: Int = 0
    var selectedBGM: BGMTrack?
    var bgmVolume: Float
    var bgmTracks: [BGMTrack] = []
    var showBGMSettingsSheet: Bool = false
    var subtitleSheetState: SubtitleSheetState?
    var isExporting: Bool = false
    var exportProgress: Double = 0
    var errorMessage: String?
    var player: AVPlayer?
    var missingSegmentOrders: [Int] = []
    var recoveryNotice: String?

    // MARK: - Dependencies

    private let exportVideoUseCase: ExportVideoUseCase
    private let fetchBGMTracksUseCase: FetchBGMTracksUseCase
    private let saveSubtitleUseCase: SaveSubtitleUseCase
    private let deleteSubtitleUseCase: DeleteSubtitleUseCase
    private let saveBGMSettingsUseCase: SaveBGMSettingsUseCase
    private let downloadBGMUseCase: DownloadBGMUseCase
    private let updateSubtitlePositionUseCase: UpdateSubtitlePositionUseCase
    private let recoverVideoAssetsUseCase: RecoverVideoAssetsUseCase?
    private let workflowManager: PreviewWorkflowManager?
    private let timePrecision: Double = 100

    // MARK: - Playback Control

    private var timeObserverToken: Any?
    private var playbackFallbackTask: Task<Void, Never>?
    private var wasPlayingBeforeScrub: Bool = false
    private(set) var isUserScrubbingTimeline: Bool = false
    private(set) var isSeekingProgrammatically: Bool = false

    private struct PlayerItemBuildResult {
        let item: AVPlayerItem?
        let targetAssetCount: Int
        let resolvedAssetCount: Int
        let insertedAssetCount: Int
    }

    // MARK: - Computed

    var subtitles: [Subtitle] {
        project.subtitles.sorted { lhs, rhs in
            if lhs.startSeconds == rhs.startSeconds {
                return lhs.endSeconds < rhs.endSeconds
            }
            return lhs.startSeconds < rhs.startSeconds
        }
    }

    var segmentTimelineItems: [SegmentTimelineItem] {
        var assetsByOrder: [Int: VideoAsset] = [:]
        for asset in project.videoAssets {
            guard let order = asset.segmentOrder else { continue }
            if assetsByOrder[order] == nil {
                assetsByOrder[order] = asset
            }
        }

        return orderedSegments.map { segment in
            let subtitle = subtitleForSegment(segment)
            let asset = assetsByOrder[segment.order]
            return SegmentTimelineItem(
                id: segment.order,
                segmentOrder: segment.order,
                startSeconds: segment.startSeconds,
                endSeconds: segment.endSeconds,
                videoLocalFileURL: asset?.localFileURL,
                subtitleId: subtitle?.id,
                subtitleText: subtitle?.text
            )
        }
    }

    var activeSubtitleText: String {
        activeSubtitle(at: currentTime)?.text ?? ""
    }

    // MARK: - Init

    init(
        project: Project,
        exportVideoUseCase: ExportVideoUseCase,
        fetchBGMTracksUseCase: FetchBGMTracksUseCase,
        saveSubtitleUseCase: SaveSubtitleUseCase,
        deleteSubtitleUseCase: DeleteSubtitleUseCase,
        saveBGMSettingsUseCase: SaveBGMSettingsUseCase,
        downloadBGMUseCase: DownloadBGMUseCase,
        updateSubtitlePositionUseCase: UpdateSubtitlePositionUseCase,
        recoverVideoAssetsUseCase: RecoverVideoAssetsUseCase? = nil,
        workflowManager: PreviewWorkflowManager? = nil
    ) {
        self.project = project
        self.exportVideoUseCase = exportVideoUseCase
        self.fetchBGMTracksUseCase = fetchBGMTracksUseCase
        self.saveSubtitleUseCase = saveSubtitleUseCase
        self.deleteSubtitleUseCase = deleteSubtitleUseCase
        self.saveBGMSettingsUseCase = saveBGMSettingsUseCase
        self.downloadBGMUseCase = downloadBGMUseCase
        self.updateSubtitlePositionUseCase = updateSubtitlePositionUseCase
        self.recoverVideoAssetsUseCase = recoverVideoAssetsUseCase
        self.workflowManager = workflowManager
        self.bgmVolume = project.bgmVolume
    }

    // MARK: - Public Methods

    func loadProject() async {
        errorMessage = nil
        missingSegmentOrders = []
        recoveryNotice = nil

        if let recoverVideoAssetsUseCase {
            let recoveryResult = await recoverVideoAssetsUseCase.execute(project: project)
            missingSegmentOrders = recoveryResult.missingSegmentOrders
            if !recoveryResult.messages.isEmpty {
                recoveryNotice = recoveryResult.messages.joined(separator: "\n")
            }
        }

        duration = computedDuration()
        bgmVolume = project.bgmVolume

        await setupPlayer()
        seek(to: currentTime, shouldSeekPlayer: false)

        do {
            bgmTracks = try await fetchBGMTracksUseCase.execute()
            selectedBGM = bgmTracks.first { $0.id == project.selectedBGMId }
        } catch {
            errorMessage = "BGM一覧の取得に失敗しました"
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func togglePlayPause() {
        if isPlaying {
            pausePlayback()
            return
        }

        if currentTime >= duration, duration > 0 {
            seek(to: 0)
        }

        if let player {
            player.play()
            isPlaying = true
        } else {
            isPlaying = true
            startFallbackPlaybackIfNeeded()
        }
    }

    func seek(to time: Double) {
        seek(to: time, shouldSeekPlayer: true)
    }

    func beginTimelineScrub() {
        guard !isUserScrubbingTimeline else { return }
        isUserScrubbingTimeline = true
        wasPlayingBeforeScrub = isPlaying
        pausePlayback()
    }

    func endTimelineScrub() {
        guard isUserScrubbingTimeline else { return }
        isUserScrubbingTimeline = false

        if wasPlayingBeforeScrub {
            togglePlayPause()
        }
        wasPlayingBeforeScrub = false
    }

    func activeSubtitle(at time: Double) -> Subtitle? {
        guard let (_, segment) = segmentContext(at: time) else { return nil }
        return subtitleForSegment(segment)
    }

    func showSubtitleSheet(for segmentOrder: Int) {
        guard let segment = orderedSegments.first(where: { $0.order == segmentOrder }) else {
            return
        }
        let subtitle = subtitleForSegment(segment)
        subtitleSheetState = SubtitleSheetState(
            segmentOrder: segment.order,
            subtitleId: subtitle?.id,
            startSeconds: segment.startSeconds,
            endSeconds: segment.endSeconds,
            text: subtitle?.text ?? ""
        )
    }

    func dismissSubtitleSheet() {
        subtitleSheetState = nil
    }

    @discardableResult
    func saveSubtitle(_ draft: SubtitleSheetState) async -> String? {
        guard let segment = orderedSegments.first(where: { $0.order == draft.segmentOrder }) else {
            return "対象セグメントが見つかりません"
        }

        do {
            try await saveSubtitleUseCase.upsertForSegment(
                project: project,
                segment: segment,
                text: draft.text,
                preferredSubtitleId: draft.subtitleId
            )
            subtitleSheetState = nil
            seek(to: currentTime, shouldSeekPlayer: false)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    @discardableResult
    func deleteSubtitle(subtitleId: UUID) async -> Bool {
        do {
            try await deleteSubtitleUseCase.execute(project: project, subtitleId: subtitleId)
            subtitleSheetState = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func saveBGMSettings(track: BGMTrack?, volume: Float) async -> Bool {
        do {
            try await saveBGMSettingsUseCase.execute(
                project: project,
                selectedBGMId: track?.id,
                bgmVolume: volume
            )
            selectedBGM = track
            bgmVolume = volume
            showBGMSettingsSheet = false
            return true
        } catch {
            errorMessage = "BGM設定の保存に失敗しました"
            return false
        }
    }

    func updateSubtitlePosition(
        subtitleId: UUID,
        positionXRatio: Double,
        positionYRatio: Double
    ) {
        guard let subtitle = project.subtitles.first(where: { $0.id == subtitleId }) else {
            errorMessage = UpdateSubtitlePositionError.subtitleNotFound.localizedDescription
            return
        }

        let clampedX = min(max(positionXRatio, 0), 1)
        let clampedY = min(max(positionYRatio, 0), 1)
        subtitle.positionXRatio = clampedX
        subtitle.positionYRatio = clampedY

        Task {
            do {
                try await updateSubtitlePositionUseCase.execute(
                    project: project,
                    subtitleId: subtitleId,
                    positionXRatio: clampedX,
                    positionYRatio: clampedY
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func exportVideo() async -> URL? {
        isExporting = true
        exportProgress = 0
        errorMessage = nil
        defer {
            isExporting = false
            exportProgress = 0
        }

        do {
            var bgmLocalURL: URL?
            if let selectedBGM {
                bgmLocalURL = try await downloadBGMUseCase.execute(track: selectedBGM)
            }

            let url = try await exportVideoUseCase.execute(
                project: project,
                bgmLocalURL: bgmLocalURL,
                bgmVolume: bgmVolume,
                progressHandler: { [weak self] progress in
                    self?.exportProgress = progress
                }
            )
            if let workflowManager {
                try? await workflowManager.markCompleted(project: project)
            }
            return url
        } catch {
            errorMessage = "書き出しに失敗しました: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Private Methods

    private func pausePlayback() {
        isPlaying = false
        player?.pause()
        playbackFallbackTask?.cancel()
        playbackFallbackTask = nil
    }

    private func setupPlayer() async {
        teardownPlayerObserver()

        let buildResult = await createPlayerItem()
        logger.info(
            "setupPlayer target=\(buildResult.targetAssetCount, privacy: .public) resolved=\(buildResult.resolvedAssetCount, privacy: .public) inserted=\(buildResult.insertedAssetCount, privacy: .public)"
        )

        guard let item = buildResult.item else {
            player = nil
            if buildResult.targetAssetCount > 0 {
                if buildResult.resolvedAssetCount == 0 {
                    errorMessage = "動画を読み込めませんでした。過去データの素材ファイルが見つからないため、録画画面で再取り込みしてください。"
                } else {
                    errorMessage = "動画を読み込めませんでした。素材ファイルを確認して再取り込みしてください。"
                }
            }
            return
        }

        if buildResult.insertedAssetCount < buildResult.targetAssetCount {
            errorMessage = "一部の素材ファイルを読み込めませんでした。再生可能な素材のみ表示しています。"
        }

        let player = AVPlayer(playerItem: item)
        self.player = player

        let interval = CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.playerDidUpdateTime(CMTimeGetSeconds(time))
            }
        }
    }

    private func teardownPlayerObserver() {
        if let timeObserverToken, let player {
            player.removeTimeObserver(timeObserverToken)
        }
        timeObserverToken = nil
        player?.pause()
    }

    private func createPlayerItem() async -> PlayerItemBuildResult {
        let assignedAssets = project.videoAssets.filter { $0.segmentOrder != nil }
        guard !assignedAssets.isEmpty else {
            return PlayerItemBuildResult(
                item: nil,
                targetAssetCount: 0,
                resolvedAssetCount: 0,
                insertedAssetCount: 0
            )
        }

        do {
            let buildResult = try await SegmentCompositionAssembler.build(
                videoAssets: assignedAssets,
                segments: orderedSegments,
                requiresPrimaryAudioTrack: false,
                strictOnLegacyMissingAsset: false
            )

            guard buildResult.insertedAnyTrack else {
                return PlayerItemBuildResult(
                    item: nil,
                    targetAssetCount: buildResult.targetAssetCount,
                    resolvedAssetCount: buildResult.resolvedAssetCount,
                    insertedAssetCount: buildResult.insertedAssetCount
                )
            }

            if let preferredTransform = buildResult.preferredTransform {
                buildResult.videoTrack.preferredTransform = preferredTransform
            }

            return PlayerItemBuildResult(
                item: AVPlayerItem(asset: buildResult.composition),
                targetAssetCount: buildResult.targetAssetCount,
                resolvedAssetCount: buildResult.resolvedAssetCount,
                insertedAssetCount: buildResult.insertedAssetCount
            )
        } catch {
            logger.error("Failed to build preview composition: \(error.localizedDescription, privacy: .public)")
            return PlayerItemBuildResult(
                item: nil,
                targetAssetCount: assignedAssets.count,
                resolvedAssetCount: 0,
                insertedAssetCount: 0
            )
        }
    }

    private func playerDidUpdateTime(_ time: Double) {
        guard !isUserScrubbingTimeline, !isSeekingProgrammatically else { return }

        _ = applyPlaybackTimeUpdate(time)

        if duration > 0, currentTime >= duration {
            pausePlayback()
        }
    }

    private func seek(to time: Double, shouldSeekPlayer: Bool) {
        let clamped = applyPlaybackTimeUpdate(time)

        guard shouldSeekPlayer, let player else { return }

        isSeekingProgrammatically = true
        let target = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.isSeekingProgrammatically = false
            }
        }
    }

    private func updateCurrentSegmentIndex(for time: Double) {
        guard let (index, _) = segmentContext(at: time) else {
            if let lastIndex = orderedSegments.indices.last,
               time >= orderedSegments[lastIndex].endSeconds {
                currentSegmentIndex = lastIndex
            } else {
                currentSegmentIndex = 0
            }
            return
        }

        currentSegmentIndex = index
    }

    private func clampedTime(_ value: Double) -> Double {
        let clamped: Double
        if duration > 0 {
            clamped = min(max(0, value), duration)
        } else {
            clamped = max(0, value)
        }

        // 表示・タイムライン・字幕判定で同じ時間表現を使う
        return normalizedTimelineTime(clamped)
    }

    private func applyPlaybackTimeUpdate(_ time: Double) -> Double {
        let clamped = clampedTime(time)
        currentTime = clamped
        updateCurrentSegmentIndex(for: clamped)
        return clamped
    }

    private func normalizedTimelineTime(_ value: Double) -> Double {
        if let workflowManager {
            return workflowManager.normalizeTimelineTime(
                value,
                duration: duration,
                precision: timePrecision
            )
        }
        return (value * timePrecision).rounded() / timePrecision
    }

    private func computedDuration() -> Double {
        let segmentDuration = orderedSegments.map(\.endSeconds).max() ?? 0

        if segmentDuration > 0 {
            return segmentDuration
        }

        let assignedAssets = project.videoAssets.filter { $0.segmentOrder != nil }
        return assignedAssets.reduce(0.0) { partial, asset in
            partial + max(0, asset.duration)
        }
    }

    private func startFallbackPlaybackIfNeeded() {
        guard player == nil else { return }

        playbackFallbackTask?.cancel()
        playbackFallbackTask = Task { [weak self] in
            while !Task.isCancelled {
                guard self != nil else { return }
                try? await Task.sleep(nanoseconds: 33_000_000)

                await MainActor.run {
                    guard let self else {
                        return
                    }
                    guard self.isPlaying else { return }
                    let next = self.currentTime + (1.0 / 30.0)
                    self.currentTime = self.clampedTime(next)
                    self.updateCurrentSegmentIndex(for: self.currentTime)

                    if self.duration > 0, self.currentTime >= self.duration {
                        self.pausePlayback()
                    }
                }
            }
        }
    }

    private var orderedSegments: [Segment] {
        (project.template?.segments ?? []).sorted { lhs, rhs in
            if lhs.startSeconds == rhs.startSeconds {
                return lhs.order < rhs.order
            }
            return lhs.startSeconds < rhs.startSeconds
        }
    }

    private func segmentContext(at time: Double) -> (index: Int, segment: Segment)? {
        let normalizedTime = normalizedTimelineTime(time)
        for (index, segment) in orderedSegments.enumerated() {
            if normalizedTime >= segment.startSeconds && normalizedTime < segment.endSeconds {
                return (index, segment)
            }
        }
        return nil
    }

    private func subtitleForSegment(_ segment: Segment) -> Subtitle? {
        let candidates = subtitles
            .compactMap { subtitle -> (Subtitle, Double)? in
                let overlap = overlapDuration(subtitle: subtitle, segment: segment)
                guard overlap > 0 else { return nil }
                return (subtitle, overlap)
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    if lhs.0.startSeconds == rhs.0.startSeconds {
                        return lhs.0.id.uuidString < rhs.0.id.uuidString
                    }
                    return lhs.0.startSeconds < rhs.0.startSeconds
                }
                return lhs.1 > rhs.1
            }

        return candidates.first?.0
    }

    private func overlapDuration(subtitle: Subtitle, segment: Segment) -> Double {
        let start = max(subtitle.startSeconds, segment.startSeconds)
        let end = min(subtitle.endSeconds, segment.endSeconds)
        return max(0, end - start)
    }
}
