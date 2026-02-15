import Foundation

// MARK: - Error

enum ExportError: Error, Equatable {
    case noVideoAssets
    case exportFailed(String)
    case projectNotFound

    static func == (lhs: ExportError, rhs: ExportError) -> Bool {
        switch (lhs, rhs) {
        case (.noVideoAssets, .noVideoAssets): return true
        case (.projectNotFound, .projectNotFound): return true
        case (.exportFailed(let a), .exportFailed(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - VideoExporterProtocol

protocol VideoExporterProtocol: Sendable {
    func export(
        videoAssets: [VideoAsset],
        subtitles: [Subtitle],
        segments: [Segment],
        bgmURL: URL?,
        bgmVolume: Float,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> URL
}

extension VideoExporter: VideoExporterProtocol {}

// MARK: - ExportVideoUseCase

@MainActor
final class ExportVideoUseCase {

    // MARK: - Properties

    private let repository: ProjectRepositoryProtocol
    private let videoExporter: VideoExporterProtocol

    // MARK: - Init

    init(repository: ProjectRepositoryProtocol, videoExporter: VideoExporterProtocol = VideoExporter()) {
        self.repository = repository
        self.videoExporter = videoExporter
    }

    // MARK: - Execute

    /// 動画を書き出す
    /// - Parameters:
    ///   - project: プロジェクト
    ///   - bgmLocalURL: ローカル保存済みBGM URL（nilの場合はBGMなし）
    ///   - bgmVolume: BGM音量（0.0 - 1.0）
    ///   - progressHandler: 進捗ハンドラ（0.0 - 1.0）
    /// - Returns: 書き出された動画ファイルのURL
    func execute(
        project: Project,
        bgmLocalURL: URL?,
        bgmVolume: Float,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {
        let assignedAssets = project.videoAssets.filter { $0.segmentOrder != nil }
        guard !assignedAssets.isEmpty else {
            throw ExportError.noVideoAssets
        }

        let segments = project.template?.segments ?? []

        let sendableHandler: @Sendable (Double) -> Void = { progress in
            Task { @MainActor in
                progressHandler(progress)
            }
        }

        return try await videoExporter.export(
            videoAssets: assignedAssets,
            subtitles: project.subtitles,
            segments: segments,
            bgmURL: bgmLocalURL,
            bgmVolume: bgmVolume,
            progressHandler: sendableHandler
        )
    }
}
