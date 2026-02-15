import Foundation

@MainActor
final class SaveVideoAssetUseCase {

    // MARK: - Properties

    private let repository: ProjectRepositoryProtocol
    private let localVideoStorage: LocalVideoStorage

    // MARK: - Init

    init(
        repository: ProjectRepositoryProtocol,
        localVideoStorage: LocalVideoStorage
    ) {
        self.repository = repository
        self.localVideoStorage = localVideoStorage
    }

    // MARK: - Execute

    /// 動画素材をプロジェクトに保存する
    /// - Parameters:
    ///   - project: 対象プロジェクト
    ///   - localFileURL: 永続化済みのローカルURL
    ///   - duration: 動画の長さ（秒）
    ///   - segmentOrder: セグメント番号（nilの場合はストック動画として保存）
    ///   - trimStartSeconds: トリム開始位置（秒）
    func execute(
        project: Project,
        localFileURL: URL,
        duration: Double,
        segmentOrder: Int?,
        trimStartSeconds: Double = 0.0,
        photoAssetIdentifier: String? = nil,
        videoAssetId: UUID = UUID()
    ) async throws {
        let path = localFileURL.standardizedFileURL.path
        let videoAsset = VideoAsset(
            id: videoAssetId,
            segmentOrder: segmentOrder,
            localFileURL: path,
            duration: duration,
            trimStartSeconds: trimStartSeconds,
            photoAssetIdentifier: photoAssetIdentifier
        )

        if let order = segmentOrder {
            // 既存のVideoAssetがあれば削除（上書き）
            if let existingIndex = project.videoAssets.firstIndex(where: { $0.segmentOrder == order }) {
                let removed = project.videoAssets.remove(at: existingIndex)
                try removeOrphanedFileIfNeeded(
                    removedPath: removed.localFileURL,
                    currentAssets: project.videoAssets
                )
            }
        }

        project.videoAssets.append(videoAsset)
        project.updatedAt = Date()

        try await repository.save(project)
    }

    private func removeOrphanedFileIfNeeded(
        removedPath: String,
        currentAssets: [VideoAsset]
    ) throws {
        guard !removedPath.isEmpty else { return }
        let removedComparable = comparablePath(from: removedPath)
        let stillReferenced = currentAssets.contains { asset in
            comparablePath(from: asset.localFileURL) == removedComparable
        }
        guard !stillReferenced else { return }
        try localVideoStorage.removeManagedVideo(atPath: removedPath)
    }

    private func comparablePath(from rawValue: String) -> String {
        if let resolved = VideoAssetPathResolver.resolveLocalURL(from: rawValue) {
            return resolved.standardizedFileURL.path
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if let url = URL(string: trimmed), url.isFileURL {
            return url.standardizedFileURL.path
        }

        if trimmed.hasPrefix("/") {
            return URL(fileURLWithPath: trimmed).standardizedFileURL.path
        }

        return trimmed
    }
}
