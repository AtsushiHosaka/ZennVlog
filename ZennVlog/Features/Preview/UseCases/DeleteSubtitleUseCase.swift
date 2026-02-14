import Foundation

@MainActor
final class DeleteSubtitleUseCase {

    // MARK: - Properties

    private let repository: ProjectRepositoryProtocol

    // MARK: - Init

    init(repository: ProjectRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute(project: Project, subtitleId: UUID) async throws {
        project.subtitles.removeAll { $0.id == subtitleId }
        try await repository.save(project)
    }
}
