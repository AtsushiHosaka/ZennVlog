import Foundation

@MainActor
final class SaveBGMSettingsUseCase {

    // MARK: - Properties

    private let repository: ProjectRepositoryProtocol

    // MARK: - Init

    init(repository: ProjectRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute(
        project: Project,
        selectedBGMId: String?,
        bgmVolume: Float
    ) async throws {
        project.selectedBGMId = selectedBGMId
        project.bgmVolume = bgmVolume
        try await repository.save(project)
    }
}
