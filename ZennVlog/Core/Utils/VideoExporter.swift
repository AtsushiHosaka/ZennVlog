import AVFoundation
import CoreImage
import UIKit

actor VideoExporter {

    // MARK: - Error

    enum VideoExporterError: Error {
        case compositionFailed(String)
        case exportSessionFailed(String)
        case noVideoTracks
        case assetLoadFailed(String)
    }

    // MARK: - Export

    /// 動画素材を結合し、テロップ・BGMを合成して書き出す
    /// - Parameters:
    ///   - videoAssets: セグメントに割り当てられた動画素材
    ///   - subtitles: テロップ一覧
    ///   - segments: テンプレートのセグメント一覧
    ///   - bgmURL: BGMファイルのURL（nilの場合はBGMなし）
    ///   - bgmVolume: BGM音量（0.0 - 1.0）
    ///   - progressHandler: 進捗ハンドラ（0.0 - 1.0）
    /// - Returns: 書き出された動画ファイルのURL
    func export(
        videoAssets: [VideoAsset],
        subtitles: [Subtitle],
        segments: [Segment],
        bgmURL: URL?,
        bgmVolume: Float,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        // 1. セグメント順にソート
        let sortedAssets = videoAssets
            .filter { $0.segmentOrder != nil }
            .sorted { ($0.segmentOrder ?? 0) < ($1.segmentOrder ?? 0) }

        guard !sortedAssets.isEmpty else {
            throw VideoExporterError.noVideoTracks
        }

        // 2. コンポジション作成
        let composition = AVMutableComposition()

        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoExporterError.compositionFailed("コンポジショントラックの作成に失敗しました")
        }

        var currentTime = CMTime.zero
        var videoSize = CGSize(width: 1920, height: 1080)

        // 3. 各動画素材をコンポジションに追加
        for asset in sortedAssets {
            let url = URL(fileURLWithPath: asset.localFileURL)
            let avAsset = AVURLAsset(url: url)

            // セグメントの長さを取得（trimStartSeconds + セグメント長で切り出し）
            let segmentDuration: Double
            if let segmentOrder = asset.segmentOrder,
               let segment = segments.first(where: { $0.order == segmentOrder }) {
                segmentDuration = segment.endSeconds - segment.startSeconds
            } else {
                segmentDuration = asset.duration
            }

            let startTime = CMTime(seconds: asset.trimStartSeconds, preferredTimescale: 600)
            let clipDuration = CMTime(seconds: segmentDuration, preferredTimescale: 600)
            let timeRange = CMTimeRange(start: startTime, duration: clipDuration)

            // ビデオトラック追加
            if let sourceVideoTrack = try? await avAsset.loadTracks(withMediaType: .video).first {
                try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: currentTime)

                // 最初のアセットからビデオサイズを取得
                if currentTime == .zero {
                    let naturalSize = try await sourceVideoTrack.load(.naturalSize)
                    videoSize = naturalSize
                }
            }

            // オーディオトラック追加（元の動画音声）
            if let sourceAudioTrack = try? await avAsset.loadTracks(withMediaType: .audio).first {
                try audioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: currentTime)
            }

            currentTime = CMTimeAdd(currentTime, clipDuration)
        }

        // 4. BGMオーディオトラック追加
        var audioMix: AVMutableAudioMix?
        if let bgmURL {
            let bgmAsset = AVURLAsset(url: bgmURL)
            if let bgmAudioTrack = try? await bgmAsset.loadTracks(withMediaType: .audio).first,
               let bgmCompositionTrack = composition.addMutableTrack(
                   withMediaType: .audio,
                   preferredTrackID: kCMPersistentTrackID_Invalid
               ) {
                let bgmDuration = try await bgmAsset.load(.duration)

                // BGMが動画より短い場合はそのまま、長い場合はトリム
                let videoDuration = currentTime
                let bgmTimeRange = CMTimeRange(
                    start: .zero,
                    duration: min(bgmDuration, videoDuration)
                )
                try bgmCompositionTrack.insertTimeRange(bgmTimeRange, of: bgmAudioTrack, at: .zero)

                // BGM音量設定
                let mix = AVMutableAudioMix()
                let bgmParams = AVMutableAudioMixInputParameters(track: bgmCompositionTrack)
                bgmParams.setVolume(bgmVolume, at: .zero)
                mix.inputParameters = [bgmParams]
                audioMix = mix
            }
        }

        // 5. テロップオーバーレイ付きビデオコンポジション作成
        let videoComposition = createVideoComposition(
            compositionVideoTrack: videoTrack,
            size: videoSize,
            duration: currentTime,
            subtitles: subtitles,
            segments: segments
        )

        // 6. 出力ファイルパスを生成
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        // 7. エクスポートセッション作成
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw VideoExporterError.exportSessionFailed("エクスポートセッションの作成に失敗しました")
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        if let audioMix {
            exportSession.audioMix = audioMix
        }

        // 8. 進捗モニタリング
        let progressTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000)
                let progress = Double(exportSession.progress)
                progressHandler(progress)
            }
        }

        // 9. エクスポート実行
        await exportSession.export()
        progressTask.cancel()
        progressHandler(1.0)

        if let error = exportSession.error {
            throw VideoExporterError.exportSessionFailed(error.localizedDescription)
        }

        guard exportSession.status == .completed else {
            throw VideoExporterError.exportSessionFailed(
                "エクスポートがステータス \(exportSession.status.rawValue) で失敗しました"
            )
        }

        return outputURL
    }

    // MARK: - Private Methods

    /// テロップオーバーレイ付きのビデオコンポジションを作成する
    private func createVideoComposition(
        compositionVideoTrack: AVMutableCompositionTrack,
        size: CGSize,
        duration: CMTime,
        subtitles: [Subtitle],
        segments: [Segment]
    ) -> AVMutableVideoComposition {
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = size
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        // テロップ用アニメーションレイヤー
        let animationLayer = CALayer()
        animationLayer.frame = CGRect(origin: .zero, size: size)

        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: size)

        // セグメントごとのテロップレイヤー追加
        // セグメントの累積開始時刻を計算（エクスポート後のタイムライン上の位置）
        let sortedSegments = segments.sorted { $0.order < $1.order }
        var segmentStartTimes: [Int: Double] = [:]
        var cumulativeTime: Double = 0
        for segment in sortedSegments {
            segmentStartTimes[segment.order] = cumulativeTime
            cumulativeTime += segment.endSeconds - segment.startSeconds
        }

        for subtitle in subtitles {
            guard !subtitle.text.isEmpty else { continue }

            guard let segment = segments.first(where: { $0.order == subtitle.segmentOrder }) else {
                continue
            }

            let segmentDuration = segment.endSeconds - segment.startSeconds
            guard let showTime = segmentStartTimes[subtitle.segmentOrder] else { continue }
            let hideTime = showTime + segmentDuration

            let textLayer = CATextLayer()
            let fontSize: CGFloat = size.height * 0.04
            textLayer.string = subtitle.text
            textLayer.font = UIFont.boldSystemFont(ofSize: fontSize)
            textLayer.fontSize = fontSize
            textLayer.foregroundColor = UIColor.white.cgColor
            textLayer.shadowColor = UIColor.black.cgColor
            textLayer.shadowOffset = CGSize(width: 1, height: 1)
            textLayer.shadowRadius = 2
            textLayer.shadowOpacity = 0.8
            textLayer.alignmentMode = .center
            textLayer.contentsScale = UIScreen.main.scale

            let textHeight = fontSize * 2
            let bottomMargin = size.height * 0.1
            textLayer.frame = CGRect(
                x: size.width * 0.1,
                y: bottomMargin,
                width: size.width * 0.8,
                height: textHeight
            )

            // セグメントのタイミングに基づく表示/非表示アニメーション
            textLayer.opacity = 0

            let showAnimation = CABasicAnimation(keyPath: "opacity")
            showAnimation.fromValue = 0
            showAnimation.toValue = 1
            showAnimation.beginTime = AVCoreAnimationBeginTimeAtZero + showTime
            showAnimation.duration = 0.01
            showAnimation.fillMode = .forwards
            showAnimation.isRemovedOnCompletion = false

            let hideAnimation = CABasicAnimation(keyPath: "opacity")
            hideAnimation.fromValue = 1
            hideAnimation.toValue = 0
            hideAnimation.beginTime = AVCoreAnimationBeginTimeAtZero + hideTime
            hideAnimation.duration = 0.01
            hideAnimation.fillMode = .forwards
            hideAnimation.isRemovedOnCompletion = false

            textLayer.add(showAnimation, forKey: "show")
            textLayer.add(hideAnimation, forKey: "hide")

            animationLayer.addSublayer(textLayer)
        }

        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: size)
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(animationLayer)

        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        // フルデュレーションのインストラクション作成（実際のコンポジションビデオトラックを使用）
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(
            assetTrack: compositionVideoTrack
        )
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        return videoComposition
    }
}
