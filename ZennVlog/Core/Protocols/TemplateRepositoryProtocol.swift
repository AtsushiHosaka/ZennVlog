import Foundation

protocol TemplateRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [TemplateDTO]
    func fetch(by id: String) async throws -> TemplateDTO?
}
