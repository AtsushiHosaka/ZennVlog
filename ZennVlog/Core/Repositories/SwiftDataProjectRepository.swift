import Foundation
import SwiftData

@MainActor
final class SwiftDataProjectRepository: ProjectRepositoryProtocol {

    // MARK: - Properties

    private let modelContext: ModelContext

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    convenience init() {
        let schema = Schema([
            Project.self,
            Template.self,
            Segment.self,
            VideoAsset.self,
            Subtitle.self,
            ChatMessage.self
        ])
        let configuration = ModelConfiguration("ZennVlogPreviewV2")

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
            self.init(modelContext: ModelContext(container))
        } catch {
            fatalError("Failed to initialize SwiftDataProjectRepository: \(error)")
        }
    }

    // MARK: - ProjectRepositoryProtocol

    func fetchAll() async throws -> [Project] {
        let descriptor = FetchDescriptor<Project>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw ProjectRepositoryError.fetchFailed(underlying: error)
        }
    }

    func fetch(by id: UUID) async throws -> Project? {
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.id == id }
        )

        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            throw ProjectRepositoryError.fetchFailed(underlying: error)
        }
    }

    func save(_ project: Project) async throws {
        do {
            if project.modelContext == nil {
                modelContext.insert(project)
            }

            project.updatedAt = Date()
            try modelContext.save()
        } catch {
            throw ProjectRepositoryError.saveFailed(underlying: error)
        }
    }

    func delete(_ project: Project) async throws {
        do {
            if let existing = try await fetch(by: project.id) {
                modelContext.delete(existing)
                try modelContext.save()
            }
        } catch {
            throw ProjectRepositoryError.deleteFailed(underlying: error)
        }
    }
}
