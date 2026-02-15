import Foundation

@MainActor
final class DeleteVideoAssetUseCase {

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

    /// セグメントに割り当てられた動画素材を削除する
    /// - Parameters:
    ///   - project: 対象プロジェクト
    ///   - segmentOrder: 削除するセグメントの番号
    func execute(project: Project, segmentOrder: Int) async throws {
        let removedPaths = Set(
            project.videoAssets
                .filter { $0.segmentOrder == segmentOrder }
                .map(\.localFileURL)
        )
        project.videoAssets.removeAll { $0.segmentOrder == segmentOrder }
        try removeOrphanedFiles(removedPaths: removedPaths, currentAssets: project.videoAssets)
        project.updatedAt = Date()
        try await repository.save(project)
    }

    /// 指定したVideoAssetを削除する（ストック動画の削除など）
    /// - Parameters:
    ///   - project: 対象プロジェクト
    ///   - videoAssetId: 削除するVideoAssetのID
    func execute(project: Project, videoAssetId: UUID) async throws {
        let removedPaths = Set(
            project.videoAssets
                .filter { $0.id == videoAssetId }
                .map(\.localFileURL)
        )
        project.videoAssets.removeAll { $0.id == videoAssetId }
        try removeOrphanedFiles(removedPaths: removedPaths, currentAssets: project.videoAssets)
        project.updatedAt = Date()
        try await repository.save(project)
    }

    private func removeOrphanedFiles(
        removedPaths: Set<String>,
        currentAssets: [VideoAsset]
    ) throws {
        let remainingComparablePaths = Set(currentAssets.map { comparablePath(from: $0.localFileURL) })
        for path in removedPaths {
            let removedComparablePath = comparablePath(from: path)
            if !remainingComparablePaths.contains(removedComparablePath) {
                try localVideoStorage.removeManagedVideo(atPath: path)
            }
        }
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
