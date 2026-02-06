import Foundation

@MainActor
final class FetchDashboardUseCase {

    // MARK: - Properties

    private let repository: ProjectRepositoryProtocol

    // MARK: - Init

    init(repository: ProjectRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute() async throws -> DashboardData {
        let projects = try await repository.fetchAll()

        let inProgressProjects = buildInProgressProjects(from: projects)
        let recentProjects = buildRecentProjects(from: projects)
        let completedProjects = buildCompletedProjects(from: projects)

        return DashboardData(
            inProgressProjects: inProgressProjects,
            recentProjects: recentProjects,
            completedProjects: completedProjects
        )
    }

    // MARK: - Private Methods

    private func buildInProgressProjects(from projects: [Project]) -> [InProgressProjectData] {
        projects
            .filter { project in
                // recording状態で未完了セグメントがある
                guard project.status == .recording,
                      let template = project.template else {
                    return false
                }

                let completedOrders = Set(
                    project.videoAssets
                        .compactMap { $0.segmentOrder }
                )
                let totalSegments = template.segments.count

                // 未撮影セグメントがあるかどうか
                return completedOrders.count < totalSegments
            }
            .compactMap { project -> InProgressProjectData? in
                guard let template = project.template else { return nil }

                let completedOrders = Set(
                    project.videoAssets
                        .compactMap { $0.segmentOrder }
                )
                let totalSegments = template.segments.count

                // 次に撮るセグメントを特定
                let sortedSegments = template.segments.sorted { $0.order < $1.order }
                guard let nextSegment = sortedSegments.first(where: { !completedOrders.contains($0.order) }) else {
                    return nil
                }

                return InProgressProjectData(
                    projectId: project.id,
                    name: project.name,
                    nextSegmentOrder: nextSegment.order,
                    nextSegmentDescription: nextSegment.segmentDescription,
                    completedSegments: completedOrders.count,
                    totalSegments: totalSegments
                )
            }
    }

    private func buildRecentProjects(from projects: [Project]) -> [RecentProjectData] {
        projects
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(10)
            .map { project in
                RecentProjectData(
                    projectId: project.id,
                    name: project.name,
                    status: project.status,
                    updatedAt: project.updatedAt
                )
            }
    }

    private func buildCompletedProjects(from projects: [Project]) -> [CompletedProjectData] {
        projects
            .filter { $0.status == .completed }
            .sorted { $0.createdAt > $1.createdAt }
            .map { project in
                CompletedProjectData(
                    projectId: project.id,
                    name: project.name,
                    status: project.status,
                    createdAt: project.createdAt
                )
            }
    }
}
