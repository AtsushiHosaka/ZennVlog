import Foundation

@MainActor
protocol ProjectRepositoryProtocol {
    func fetchAll() async throws -> [Project]
    func fetch(by id: UUID) async throws -> Project?
    func save(_ project: Project) async throws
    func delete(_ project: Project) async throws
}
