import Foundation

struct DashboardData {
    let inProgressProjects: [InProgressProjectData]
    let recentProjects: [RecentProjectData]
    let completedProjects: [CompletedProjectData]
}

struct InProgressProjectData: Identifiable, Equatable {
    let projectId: UUID
    let name: String
    let nextSegmentOrder: Int
    let nextSegmentDescription: String
    let completedSegments: Int
    let totalSegments: Int

    var id: UUID { projectId }
}

struct RecentProjectData: Identifiable, Equatable {
    let projectId: UUID
    let name: String
    let status: ProjectStatus
    let updatedAt: Date

    var id: UUID { projectId }
}

struct CompletedProjectData: Identifiable, Equatable {
    let projectId: UUID
    let name: String
    let status: ProjectStatus
    let createdAt: Date

    var id: UUID { projectId }
}
