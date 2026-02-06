import AVFoundation
import Foundation

@MainActor
final class TrimVideoUseCase {

    // MARK: - Error

    enum TrimError: Error {
        case exportFailed(Error)
        case invalidTimeRange
        case assetLoadFailed
    }

    // MARK: - Execute

    /// 動画をトリムする
    /// - Parameters:
    ///   - videoURL: 元の動画URL
    ///   - startSeconds: トリム開始時刻（秒）
    ///   - duration: トリム範囲の長さ（秒）
    /// - Returns: トリムされた動画のURL
    func execute(
        videoURL: URL,
        startSeconds: Double,
        duration: Double
    ) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)

        // 出力ファイルパスを生成
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        // 時間範囲を設定
        let startTime = CMTime(seconds: startSeconds, preferredTimescale: 600)
        let durationTime = CMTime(seconds: duration, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: startTime, duration: durationTime)

        // アセットの長さを確認
        let assetDuration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(assetDuration)

        guard startSeconds >= 0,
              startSeconds + duration <= totalSeconds else {
            throw TrimError.invalidTimeRange
        }

        // エクスポートセッションを作成
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw TrimError.assetLoadFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.timeRange = timeRange

        // エクスポート実行
        await exportSession.export()

        if let error = exportSession.error {
            throw TrimError.exportFailed(error)
        }

        guard exportSession.status == .completed else {
            throw TrimError.exportFailed(
                NSError(domain: "TrimVideoUseCase", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Export failed with status: \(exportSession.status.rawValue)"
                ])
            )
        }

        return outputURL
    }
}
