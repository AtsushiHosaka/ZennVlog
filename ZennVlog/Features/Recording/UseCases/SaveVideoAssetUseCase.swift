import Foundation

@MainActor
final class SaveVideoAssetUseCase {

    // MARK: - Properties

    private let repository: ProjectRepositoryProtocol

    // MARK: - Init

    init(repository: ProjectRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Execute

    /// 動画素材をプロジェクトに保存する
    /// - Parameters:
    ///   - project: 対象プロジェクト
    ///   - localFileURL: ローカルファイルパス
    ///   - duration: 動画の長さ（秒）
    ///   - segmentOrder: セグメント番号（nilの場合はストック動画として保存）
    ///   - trimStartSeconds: トリム開始位置（秒）
    func execute(
        project: Project,
        localFileURL: String,
        duration: Double,
        segmentOrder: Int?,
        trimStartSeconds: Double = 0.0
    ) async throws {
        let videoAsset = VideoAsset(
            segmentOrder: segmentOrder,
            localFileURL: localFileURL,
            duration: duration,
            trimStartSeconds: trimStartSeconds
        )

        if let order = segmentOrder {
            // 既存のVideoAssetがあれば削除（上書き）
            if let existingIndex = project.videoAssets.firstIndex(where: { $0.segmentOrder == order }) {
                project.videoAssets.remove(at: existingIndex)
            }
        }

        project.videoAssets.append(videoAsset)
        project.updatedAt = Date()

        try await repository.save(project)
    }
}
