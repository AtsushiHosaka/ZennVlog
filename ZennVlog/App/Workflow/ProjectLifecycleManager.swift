import Foundation

@MainActor
final class ProjectLifecycleManager {
    private let repository: ProjectRepositoryProtocol

    init(repository: ProjectRepositoryProtocol) {
        self.repository = repository
    }

    func markRecording(_ project: Project) async throws {
        project.status = .recording
        project.updatedAt = Date()
        try await repository.save(project)
    }

    @discardableResult
    func markEditingIfReady(_ project: Project) async throws -> Bool {
        guard hasAllRequiredSegmentAssets(project) else {
            return false
        }
        project.status = .editing
        project.updatedAt = Date()
        try await repository.save(project)
        return true
    }

    func markCompleted(_ project: Project) async throws {
        project.status = .completed
        project.updatedAt = Date()
        try await repository.save(project)
    }

    private func hasAllRequiredSegmentAssets(_ project: Project) -> Bool {
        guard let template = project.template else { return false }
        let requiredOrders = Set(template.segments.map(\.order))
        let recordedOrders = Set(project.videoAssets.compactMap(\.segmentOrder))
        return !requiredOrders.isEmpty && requiredOrders.isSubset(of: recordedOrders)
    }
}
