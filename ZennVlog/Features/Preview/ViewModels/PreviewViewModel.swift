import AVFoundation
import Foundation
import Observation

struct SubtitleSheetState: Identifiable, Equatable {
    let id: UUID
    let subtitleId: UUID?
    var startSeconds: Double
    var endSeconds: Double
    var text: String

    init(
        subtitleId: UUID? = nil,
        startSeconds: Double,
        endSeconds: Double,
        text: String
    ) {
        self.subtitleId = subtitleId
        self.id = subtitleId ?? UUID()
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.text = text
    }
}

struct VideoTimelineSegment: Identifiable, Equatable {
    let id: Int
    let order: Int
    let startSeconds: Double
    let endSeconds: Double
    let localFileURL: String?

    var duration: Double {
        max(0, endSeconds - startSeconds)
    }
}

@MainActor
@Observable
final class PreviewViewModel {

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

    // MARK: - Dependencies

    private let exportVideoUseCase: ExportVideoUseCase
    private let fetchBGMTracksUseCase: FetchBGMTracksUseCase
    private let saveSubtitleUseCase: SaveSubtitleUseCase
    private let deleteSubtitleUseCase: DeleteSubtitleUseCase
    private let saveBGMSettingsUseCase: SaveBGMSettingsUseCase
    private let downloadBGMUseCase: DownloadBGMUseCase
    private let updateSubtitlePositionUseCase: UpdateSubtitlePositionUseCase
    private let timePrecision: Double = 100

    // MARK: - Playback Control

    private var timeObserverToken: Any?
    private var playbackFallbackTask: Task<Void, Never>?
    private var wasPlayingBeforeScrub: Bool = false
    private(set) var isUserScrubbingTimeline: Bool = false
    private(set) var isSeekingProgrammatically: Bool = false

    // MARK: - Computed

    var subtitles: [Subtitle] {
        project.subtitles.sorted { lhs, rhs in
            if lhs.startSeconds == rhs.startSeconds {
                return lhs.endSeconds < rhs.endSeconds
            }
            return lhs.startSeconds < rhs.startSeconds
        }
    }

    var activeSubtitleText: String {
        activeSubtitle(at: currentTime)?.text ?? ""
    }

    var timelineSegments: [VideoTimelineSegment] {
        let segments = project.template?.segments.sorted { $0.order < $1.order } ?? []
        return segments.map { segment in
            let asset = project.videoAssets.first { $0.segmentOrder == segment.order }
            return VideoTimelineSegment(
                id: segment.order,
                order: segment.order,
                startSeconds: segment.startSeconds,
                endSeconds: segment.endSeconds,
                localFileURL: asset?.localFileURL
            )
        }
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
        updateSubtitlePositionUseCase: UpdateSubtitlePositionUseCase
    ) {
        self.project = project
        self.exportVideoUseCase = exportVideoUseCase
        self.fetchBGMTracksUseCase = fetchBGMTracksUseCase
        self.saveSubtitleUseCase = saveSubtitleUseCase
        self.deleteSubtitleUseCase = deleteSubtitleUseCase
        self.saveBGMSettingsUseCase = saveBGMSettingsUseCase
        self.downloadBGMUseCase = downloadBGMUseCase
        self.updateSubtitlePositionUseCase = updateSubtitlePositionUseCase
        self.bgmVolume = project.bgmVolume
    }

    // MARK: - Public Methods

    func loadProject() async {
        errorMessage = nil

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
        let normalizedTime = normalizedTimelineTime(time)
        return subtitles.first { subtitle in
            let start = normalizedTimelineTime(subtitle.startSeconds)
            let end = normalizedTimelineTime(subtitle.endSeconds)
            return normalizedTime >= start && normalizedTime < end
        }
    }

    func showNewSubtitleSheet(at time: Double? = nil) {
        let start = max(0, min(time ?? currentTime, max(duration - 0.1, 0)))
        let defaultLength = 2.0
        let tentativeEnd = start + defaultLength
        let maxEnd = duration > 0 ? duration : tentativeEnd
        let end = max(start + 0.1, min(tentativeEnd, maxEnd))

        subtitleSheetState = SubtitleSheetState(
            startSeconds: start,
            endSeconds: end,
            text: ""
        )
    }

    func showEditSubtitleSheet(_ subtitle: Subtitle) {
        subtitleSheetState = SubtitleSheetState(
            subtitleId: subtitle.id,
            startSeconds: subtitle.startSeconds,
            endSeconds: subtitle.endSeconds,
            text: subtitle.text
        )
    }

    func dismissSubtitleSheet() {
        subtitleSheetState = nil
    }

    @discardableResult
    func saveSubtitle(_ draft: SubtitleSheetState) async -> Bool {
        do {
            try await saveSubtitleUseCase.execute(
                project: project,
                subtitleId: draft.subtitleId,
                startSeconds: draft.startSeconds,
                endSeconds: draft.endSeconds,
                text: draft.text
            )
            subtitleSheetState = nil
            seek(to: currentTime, shouldSeekPlayer: false)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
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
            if let selectedBGM {
                _ = try? await downloadBGMUseCase.execute(track: selectedBGM)
            }

            let url = try await exportVideoUseCase.execute(
                project: project,
                bgmTrack: selectedBGM,
                bgmVolume: bgmVolume,
                progressHandler: { [weak self] progress in
                    self?.exportProgress = progress
                }
            )
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

        guard let item = await createPlayerItem() else {
            player = nil
            return
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

    private func createPlayerItem() async -> AVPlayerItem? {
        let sortedAssets = project.videoAssets
            .filter { $0.segmentOrder != nil }
            .sorted { ($0.segmentOrder ?? 0) < ($1.segmentOrder ?? 0) }

        guard !sortedAssets.isEmpty else {
            return nil
        }

        let composition = AVMutableComposition()
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            return nil
        }

        let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        let segmentMap = Dictionary(
            uniqueKeysWithValues: (project.template?.segments ?? []).map { ($0.order, $0) }
        )

        var insertedAnyTrack = false
        var currentInsertTime = CMTime.zero

        for asset in sortedAssets {
            guard let localURL = resolveLocalVideoURL(from: asset.localFileURL) else {
                continue
            }

            let avAsset = AVURLAsset(url: localURL)
            guard let sourceVideoTrack = try? await avAsset.loadTracks(withMediaType: .video).first else {
                continue
            }

            let assetDurationTime = (try? await avAsset.load(.duration)) ?? CMTime(seconds: asset.duration, preferredTimescale: 600)
            let assetDuration = CMTimeGetSeconds(assetDurationTime)
            guard assetDuration.isFinite, assetDuration > 0 else {
                continue
            }

            let targetDuration: Double
            if let order = asset.segmentOrder, let segment = segmentMap[order] {
                targetDuration = max(0.1, segment.endSeconds - segment.startSeconds)
            } else {
                targetDuration = max(0.1, asset.duration)
            }

            let availableDuration = max(0, assetDuration - asset.trimStartSeconds)
            guard availableDuration > 0 else {
                continue
            }

            let clipDuration = min(targetDuration, availableDuration)
            let sourceStart = CMTime(seconds: asset.trimStartSeconds, preferredTimescale: 600)
            let sourceDuration = CMTime(seconds: clipDuration, preferredTimescale: 600)
            let sourceRange = CMTimeRange(start: sourceStart, duration: sourceDuration)

            do {
                try compositionVideoTrack.insertTimeRange(sourceRange, of: sourceVideoTrack, at: currentInsertTime)

                if let sourceAudioTrack = try? await avAsset.loadTracks(withMediaType: .audio).first,
                   let compositionAudioTrack {
                    try compositionAudioTrack.insertTimeRange(sourceRange, of: sourceAudioTrack, at: currentInsertTime)
                }

                currentInsertTime = CMTimeAdd(currentInsertTime, sourceDuration)
                insertedAnyTrack = true
            } catch {
                continue
            }
        }

        guard insertedAnyTrack else {
            return nil
        }

        return AVPlayerItem(asset: composition)
    }

    private func resolveLocalVideoURL(from value: String) -> URL? {
        if let url = URL(string: value), url.isFileURL {
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return url
        }

        if value.hasPrefix("/") {
            let url = URL(fileURLWithPath: value)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return url
        }

        return nil
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
        let segments = project.template?.segments.sorted { $0.order < $1.order } ?? []

        guard let matched = segments.first(where: { segment in
            time >= segment.startSeconds && time < segment.endSeconds
        }) else {
            if let lastSegment = segments.last, time >= lastSegment.endSeconds {
                currentSegmentIndex = lastSegment.order
            } else {
                currentSegmentIndex = 0
            }
            return
        }

        currentSegmentIndex = matched.order
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
        (value * timePrecision).rounded() / timePrecision
    }

    private func computedDuration() -> Double {
        let segmentDuration = project.template?.segments.map(\.endSeconds).max() ?? 0

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
}
