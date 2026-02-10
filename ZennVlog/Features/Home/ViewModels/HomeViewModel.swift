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
    var projectForRecording: Project?
    var showRecording: Bool = false

    // MARK: - Dependencies

    private let fetchDashboardUseCase: FetchDashboardUseCase
    private let createProjectFromTemplateUseCase: CreateProjectFromTemplateUseCase

    // MARK: - Init

    init(
        fetchDashboardUseCase: FetchDashboardUseCase,
        createProjectFromTemplateUseCase: CreateProjectFromTemplateUseCase
    ) {
        self.fetchDashboardUseCase = fetchDashboardUseCase
        self.createProjectFromTemplateUseCase = createProjectFromTemplateUseCase
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

    func handleTemplateConfirmed(
        template: TemplateDTO,
        bgm: BGMTrack?
    ) async {
        do {
            let project = try await createProjectFromTemplateUseCase.execute(
                preferredName: newProjectInput,
                templateDTO: template,
                bgm: bgm
            )
            dismissChat()
            await loadDashboard()
            projectForRecording = project
            showRecording = true
        } catch {
            errorMessage = "プロジェクトの作成に失敗しました: \(error.localizedDescription)"
        }
    }
}
