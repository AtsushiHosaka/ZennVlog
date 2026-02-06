import Foundation

@MainActor
final class DeleteVideoAssetUseCase {

    // MARK: - Properties

    private let repository: ProjectRepositoryProtocol

    // MARK: - Init

    init(repository: ProjectRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Execute

    /// セグメントに割り当てられた動画素材を削除する
    /// - Parameters:
    ///   - project: 対象プロジェクト
    ///   - segmentOrder: 削除するセグメントの番号
    func execute(project: Project, segmentOrder: Int) async throws {
        project.videoAssets.removeAll { $0.segmentOrder == segmentOrder }
        project.updatedAt = Date()
        try await repository.save(project)
    }

    /// 指定したVideoAssetを削除する（ストック動画の削除など）
    /// - Parameters:
    ///   - project: 対象プロジェクト
    ///   - videoAssetId: 削除するVideoAssetのID
    func execute(project: Project, videoAssetId: UUID) async throws {
        project.videoAssets.removeAll { $0.id == videoAssetId }
        project.updatedAt = Date()
        try await repository.save(project)
    }
}
