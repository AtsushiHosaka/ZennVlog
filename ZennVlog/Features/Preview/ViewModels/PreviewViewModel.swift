import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class PreviewViewModel {

    // MARK: - Properties

    var project: Project
    var isPlaying: Bool = false
    var currentTime: Double = 0.0
    var duration: Double = 0.0
    var currentSegmentIndex: Int = 0
    var subtitleText: String = ""
    var selectedBGM: BGMTrack?
    var bgmVolume: Float = 0.3
    var bgmTracks: [BGMTrack] = []
    var showBGMSelector: Bool = false
    var isExporting: Bool = false
    var exportProgress: Double = 0.0
    var errorMessage: String?
    private(set) var exportedVideoURL: URL?

    // MARK: - Computed Properties

    var currentSubtitle: Subtitle? {
        project.subtitles.first { $0.segmentOrder == currentSegmentIndex }
    }

    var segments: [Segment] {
        project.template?.segments ?? []
    }

    // MARK: - Dependencies

    private let exportVideoUseCase: ExportVideoUseCase
    private let fetchBGMTracksUseCase: FetchBGMTracksUseCase
    private let saveSubtitleUseCase: SaveSubtitleUseCase
    private let downloadBGMUseCase: DownloadBGMUseCase

    // MARK: - Private Properties

    nonisolated(unsafe) private var player: AVPlayer?
    nonisolated(unsafe) private var timeObserver: Any?

    // MARK: - Init

    init(
        project: Project,
        exportVideoUseCase: ExportVideoUseCase,
        fetchBGMTracksUseCase: FetchBGMTracksUseCase,
        saveSubtitleUseCase: SaveSubtitleUseCase,
        downloadBGMUseCase: DownloadBGMUseCase
    ) {
        self.project = project
        self.exportVideoUseCase = exportVideoUseCase
        self.fetchBGMTracksUseCase = fetchBGMTracksUseCase
        self.saveSubtitleUseCase = saveSubtitleUseCase
        self.downloadBGMUseCase = downloadBGMUseCase
    }

    // MARK: - Public Methods

    func loadProject() async {
        await loadBGMTracks()
        restoreExistingSubtitle()
        calculateDuration()
    }

    func togglePlayPause() {
        isPlaying.toggle()
        if isPlaying {
            player?.play()
        } else {
            player?.pause()
        }
    }

    func seekToSegment(_ index: Int) {
        guard index >= 0 && index < segments.count else { return }
        let segment = segments[index]
        currentTime = Double(segment.startSeconds)
        currentSegmentIndex = index
        restoreExistingSubtitle()

        let time = CMTime(seconds: currentTime, preferredTimescale: 600)
        player?.seek(to: time)
    }

    func saveSubtitle() async {
        do {
            try await saveSubtitleUseCase.execute(
                project: project,
                segmentOrder: currentSegmentIndex,
                text: subtitleText
            )
        } catch {
            errorMessage = "テロップの保存に失敗しました"
        }
    }

    func loadBGMTracks() async {
        do {
            bgmTracks = try await fetchBGMTracksUseCase.execute()

            if let bgmId = project.selectedBGMId {
                selectedBGM = bgmTracks.first { $0.id == bgmId }
            }
        } catch {
            errorMessage = "BGM一覧の取得に失敗しました"
        }
    }

    func selectBGM(_ track: BGMTrack) async {
        do {
            _ = try await downloadBGMUseCase.execute(track: track)
            selectedBGM = track
            project.selectedBGMId = track.id
            showBGMSelector = false
        } catch {
            errorMessage = "BGMのダウンロードに失敗しました"
        }
    }

    func exportVideo() async {
        isExporting = true
        exportProgress = 0.0

        do {
            let url = try await exportVideoUseCase.execute(
                project: project,
                bgmTrack: selectedBGM,
                bgmVolume: bgmVolume,
                progressHandler: { [weak self] progress in
                    Task { @MainActor in
                        self?.exportProgress = progress
                    }
                }
            )
            exportedVideoURL = url
        } catch {
            errorMessage = "動画の書き出しに失敗しました"
        }

        isExporting = false
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Private Methods

    private func updateCurrentSegment(time: Double) {
        guard let index = segments.firstIndex(where: {
            Double($0.startSeconds) <= time && time < Double($0.endSeconds)
        }) else { return }

        if currentSegmentIndex != index {
            currentSegmentIndex = index
            restoreExistingSubtitle()
        }
    }

    private func restoreExistingSubtitle() {
        if let subtitle = currentSubtitle {
            subtitleText = subtitle.text
        } else {
            subtitleText = ""
        }
    }

    private func calculateDuration() {
        duration = segments.reduce(0.0) { total, segment in
            total + Double(segment.endSeconds - segment.startSeconds)
        }
    }

    private func setupTimeObserver() {
        guard let player else { return }

        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            Task { @MainActor in
                self.currentTime = CMTimeGetSeconds(time)
                self.updateCurrentSegment(time: self.currentTime)
            }
        }
    }

    deinit {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
    }
}
