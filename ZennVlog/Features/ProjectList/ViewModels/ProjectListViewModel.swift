import Foundation
import Observation

@MainActor
@Observable
final class ProjectListViewModel {

    // MARK: - Properties

    private(set) var projects: [Project] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var projectForRecording: Project?
    var showRecording: Bool = false

    private let fetchProjectsUseCase: FetchProjectsUseCase
    private let createProjectFromTemplateUseCase: CreateProjectFromTemplateUseCase

    // MARK: - Init

    init(
        fetchProjectsUseCase: FetchProjectsUseCase,
        createProjectFromTemplateUseCase: CreateProjectFromTemplateUseCase
    ) {
        self.fetchProjectsUseCase = fetchProjectsUseCase
        self.createProjectFromTemplateUseCase = createProjectFromTemplateUseCase
    }

    // MARK: - Public Methods

    func loadProjects() async {
        isLoading = true
        errorMessage = nil

        do {
            projects = try await fetchProjectsUseCase.execute()
        } catch {
            projects = []
            errorMessage = "プロジェクトの取得に失敗しました: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func refresh() async {
        await loadProjects()
    }

    func handleTemplateConfirmed(
        template: TemplateDTO
    ) async {
        do {
            let project = try await createProjectFromTemplateUseCase.execute(
                preferredName: nil,
                templateDTO: template,
                bgm: nil
            )
            await loadProjects()
            projectForRecording = project
            showRecording = true
        } catch {
            errorMessage = "プロジェクトの作成に失敗しました: \(error.localizedDescription)"
        }
    }
}
