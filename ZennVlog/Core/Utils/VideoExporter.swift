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
        let assignedAssets = videoAssets.filter { $0.segmentOrder != nil }
        guard !assignedAssets.isEmpty else {
            throw VideoExporterError.noVideoTracks
        }

        let assembled: SegmentCompositionAssembler.BuildResult
        do {
            assembled = try await SegmentCompositionAssembler.build(
                videoAssets: assignedAssets,
                segments: segments,
                requiresPrimaryAudioTrack: true,
                strictOnLegacyMissingAsset: true
            )
        } catch let error as SegmentCompositionAssemblerError {
            switch error {
            case .videoTrackCreationFailed, .audioTrackCreationFailed:
                throw VideoExporterError.compositionFailed("コンポジショントラックの作成に失敗しました")
            case .legacyAssetNotFound(let path):
                throw VideoExporterError.assetLoadFailed("動画ファイルが見つかりません: \(path)")
            case .legacyAssetInvalidDuration(let fileName):
                throw VideoExporterError.assetLoadFailed("動画の長さが不正です: \(fileName)")
            case .legacyTrimOutOfRange(let fileName):
                throw VideoExporterError.assetLoadFailed("trim開始位置が動画長を超えています: \(fileName)")
            }
        } catch {
            throw VideoExporterError.compositionFailed(error.localizedDescription)
        }

        guard assembled.insertedAnyTrack else {
            throw VideoExporterError.noVideoTracks
        }

        let composition = assembled.composition
        let videoTrack = assembled.videoTrack
        let currentTime = assembled.duration
        let videoSize = assembled.videoSize
        let preferredTransform = assembled.preferredTransform ?? .identity

        // 4. BGMオーディオトラック追加
        var audioMix: AVMutableAudioMix?
        if let bgmURL {
            guard bgmURL.isFileURL else {
                throw VideoExporterError.assetLoadFailed("BGMはローカルURLで指定してください")
            }
            guard FileManager.default.fileExists(atPath: bgmURL.path) else {
                throw VideoExporterError.assetLoadFailed("BGMファイルが見つかりません: \(bgmURL.lastPathComponent)")
            }

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
            preferredTransform: preferredTransform,
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
        preferredTransform: CGAffineTransform,
        subtitles: [Subtitle],
        segments _: [Segment]
    ) -> AVMutableVideoComposition {
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = size
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        // テロップ用アニメーションレイヤー
        let animationLayer = CALayer()
        animationLayer.frame = CGRect(origin: .zero, size: size)

        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: size)

        // 時間範囲ベースでテロップレイヤーを追加
        let videoDuration = CMTimeGetSeconds(duration)

        for subtitle in subtitles {
            guard !subtitle.text.isEmpty else { continue }

            let showTime = max(0, subtitle.startSeconds)
            let hideTime = min(videoDuration, subtitle.endSeconds)
            guard hideTime > showTime else { continue }

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
            let textWidth = size.width * 0.8
            let halfWidth = textWidth / 2
            let halfHeight = textHeight / 2
            let centerX = min(max(size.width * subtitle.positionXRatio, halfWidth), size.width - halfWidth)
            let centerY = min(max(size.height * subtitle.positionYRatio, halfHeight), size.height - halfHeight)
            textLayer.frame = CGRect(
                x: centerX - halfWidth,
                y: centerY - halfHeight,
                width: textWidth,
                height: textHeight
            )

            // 指定時間範囲で表示/非表示アニメーション
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
        parentLayer.isGeometryFlipped = true
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
        layerInstruction.setTransform(preferredTransform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        return videoComposition
    }

}
