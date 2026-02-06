import Foundation

@MainActor
final class FetchTemplatesUseCase {

    // MARK: - Properties

    private let repository: TemplateRepositoryProtocol

    // MARK: - Init

    init(repository: TemplateRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute() async throws -> [TemplateDTO] {
        try await repository.fetchAll()
    }

    func executeById(id: String) async throws -> TemplateDTO? {
        try await repository.fetch(by: id)
    }
}
