import Foundation

@MainActor
final class FetchProjectsUseCase {

    // MARK: - Properties

    private let repository: ProjectRepositoryProtocol

    // MARK: - Init

    init(repository: ProjectRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute() async throws -> [Project] {
        let projects = try await repository.fetchAll()
        return projects.sorted { $0.updatedAt > $1.updatedAt }
    }
}
