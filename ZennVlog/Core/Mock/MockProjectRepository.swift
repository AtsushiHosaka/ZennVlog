import Foundation

@MainActor
final class MockProjectRepository: ProjectRepositoryProtocol {

    // MARK: - Properties

    private var projects: [Project] = []
    var shouldThrowError: Bool = false

    // MARK: - Init

    init(emptyForTesting: Bool = false) {
        if !emptyForTesting {
            setupMockData()
        }
    }

    // MARK: - Testing Helpers

    func clearAll() {
        projects.removeAll()
    }

    // MARK: - ProjectRepositoryProtocol

    func fetchAll() async throws -> [Project] {
        if shouldThrowError {
            throw ProjectRepositoryError.fetchFailed(underlying: NSError(domain: "Mock", code: -1))
        }
        try await simulateNetworkDelay()
        return projects
    }

    func fetch(by id: UUID) async throws -> Project? {
        if shouldThrowError {
            throw ProjectRepositoryError.fetchFailed(underlying: NSError(domain: "Mock", code: -1))
        }
        try await simulateNetworkDelay()
        return projects.first { $0.id == id }
    }

    func save(_ project: Project) async throws {
        if shouldThrowError {
            throw ProjectRepositoryError.saveFailed(underlying: NSError(domain: "Mock", code: -1))
        }
        try await simulateNetworkDelay()
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        } else {
            projects.append(project)
        }
    }

    func delete(_ project: Project) async throws {
        if shouldThrowError {
            throw ProjectRepositoryError.deleteFailed(underlying: NSError(domain: "Mock", code: -1))
        }
        try await simulateNetworkDelay()
        projects.removeAll { $0.id == project.id }
    }

    // MARK: - Private Methods

    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
    }

    private func setupMockData() {
        let template = Template(
            segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング"),
                Segment(order: 1, startSeconds: 5, endSeconds: 15, segmentDescription: "朝の様子"),
                Segment(order: 2, startSeconds: 15, endSeconds: 30, segmentDescription: "昼の活動"),
                Segment(order: 3, startSeconds: 30, endSeconds: 45, segmentDescription: "夜のシーン"),
                Segment(order: 4, startSeconds: 45, endSeconds: 50, segmentDescription: "エンディング")
            ]
        )

        let inProgressProject = Project(
            name: "週末のお出かけVlog",
            theme: "日常",
            projectDescription: "週末に友達と出かけた様子を記録",
            template: template,
            videoAssets: [
            ],
            status: .recording
        )

        let completedProject = Project(
            name: "カフェ巡りVlog",
            theme: "グルメ",
            projectDescription: "お気に入りのカフェを紹介",
            status: .completed,
            createdAt: Date().addingTimeInterval(-86400 * 3),
            updatedAt: Date().addingTimeInterval(-86400)
        )

        projects = [inProgressProject, completedProject]
    }
}
