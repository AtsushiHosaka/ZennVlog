import Foundation

@MainActor
final class DeleteAllProjectsUseCase {

    private let repository: ProjectRepositoryProtocol

    init(repository: ProjectRepositoryProtocol) {
        self.repository = repository
    }

    func execute() async throws {
        let projects = try await repository.fetchAll()
        for project in projects {
            try await repository.delete(project)
        }
    }
}
