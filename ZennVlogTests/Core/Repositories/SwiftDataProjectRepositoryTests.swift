import Foundation
import SwiftData
import Testing
@testable import ZennVlog

@Suite("SwiftDataProjectRepository Tests")
@MainActor
struct SwiftDataProjectRepositoryTests {

    private func makeRepository() throws -> SwiftDataProjectRepository {
        let schema = Schema([
            Project.self,
            Template.self,
            Segment.self,
            VideoAsset.self,
            Subtitle.self,
            ChatMessage.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return SwiftDataProjectRepository(modelContext: ModelContext(container))
    }

    @Test("save and fetch by id")
    func saveAndFetchById() async throws {
        let repository = try makeRepository()
        let project = Project(name: "Test Project")

        try await repository.save(project)
        let fetched = try await repository.fetch(by: project.id)

        #expect(fetched?.id == project.id)
        #expect(fetched?.name == "Test Project")
    }

    @Test("fetchAll returns updatedAt descending")
    func fetchAllSortedByUpdatedAt() async throws {
        let repository = try makeRepository()

        let oldProject = Project(name: "Old", updatedAt: Date().addingTimeInterval(-3600))
        let newProject = Project(name: "New", updatedAt: Date())

        try await repository.save(oldProject)
        try await repository.save(newProject)

        let projects = try await repository.fetchAll()

        #expect(projects.count == 2)
        #expect(projects.first?.name == "New")
    }

    @Test("delete removes project")
    func deleteProject() async throws {
        let repository = try makeRepository()
        let project = Project(name: "Delete Target")

        try await repository.save(project)
        try await repository.delete(project)

        let fetched = try await repository.fetch(by: project.id)
        #expect(fetched == nil)
    }
}
