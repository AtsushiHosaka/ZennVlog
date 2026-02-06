import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {

    // MARK: - Properties

    var inProgressProjects: [InProgressProjectData] = []
    var recentProjects: [RecentProjectData] = []
    var completedProjects: [CompletedProjectData] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var showChat: Bool = false
    var newProjectInput: String = ""

    // MARK: - Dependencies

    private let fetchDashboardUseCase: FetchDashboardUseCase

    // MARK: - Init

    init(fetchDashboardUseCase: FetchDashboardUseCase) {
        self.fetchDashboardUseCase = fetchDashboardUseCase
    }

    // MARK: - Public Methods

    func loadDashboard() async {
        isLoading = true
        errorMessage = nil

        do {
            let data = try await fetchDashboardUseCase.execute()
            inProgressProjects = data.inProgressProjects
            recentProjects = data.recentProjects
            completedProjects = data.completedProjects
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func refresh() async {
        await loadDashboard()
    }

    func startNewProject() {
        showChat = true
    }

    func dismissChat() {
        showChat = false
        newProjectInput = ""
    }
}
