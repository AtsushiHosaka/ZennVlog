import Foundation
import Observation

@MainActor
@Observable
final class ProjectListViewModel {

    // MARK: - Properties

    private(set) var projects: [Project] = []
    var isLoading: Bool = false
    var errorMessage: String?

    private let fetchProjectsUseCase: FetchProjectsUseCase

    // MARK: - Init

    init(fetchProjectsUseCase: FetchProjectsUseCase) {
        self.fetchProjectsUseCase = fetchProjectsUseCase
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
}
