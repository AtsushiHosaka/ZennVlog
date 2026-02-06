import Foundation
import Testing
@testable import ZennVlog

@Suite("HomeViewModel Tests")
@MainActor
struct HomeViewModelTests {

    // MARK: - 初期状態のテスト

    @Test("初期状態が正しく設定されている")
    func 初期状態が正しく設定されている() async throws {
        // Given
        let mockRepository = MockProjectRepository(emptyForTesting: true)
        let useCase = FetchDashboardUseCase(repository: mockRepository)
        let viewModel = HomeViewModel(fetchDashboardUseCase: useCase)

        // Then
        #expect(viewModel.inProgressProjects.isEmpty)
        #expect(viewModel.recentProjects.isEmpty)
        #expect(viewModel.completedProjects.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.showChat == false)
        #expect(viewModel.newProjectInput.isEmpty)
    }

    // MARK: - loadDashboard テスト

    @Test("loadDashboard成功時にデータが更新される")
    func loadDashboard成功時にデータが更新される() async throws {
        // Given
        let mockRepository = MockProjectRepository()
        let useCase = FetchDashboardUseCase(repository: mockRepository)
        let viewModel = HomeViewModel(fetchDashboardUseCase: useCase)

        // When
        await viewModel.loadDashboard()

        // Then
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("loadDashboard中はisLoadingがtrueになる")
    func loadDashboard中はisLoadingがtrueになる() async throws {
        // Given
        let mockRepository = MockProjectRepository()
        let useCase = FetchDashboardUseCase(repository: mockRepository)
        let viewModel = HomeViewModel(fetchDashboardUseCase: useCase)

        // When
        let loadTask = Task {
            await viewModel.loadDashboard()
        }

        // 開始直後はisLoadingがtrue
        try await Task.sleep(nanoseconds: 10_000_000)
        #expect(viewModel.isLoading == true)

        await loadTask.value
    }

    @Test("loadDashboard完了後はisLoadingがfalseになる")
    func loadDashboard完了後はisLoadingがfalseになる() async throws {
        // Given
        let mockRepository = MockProjectRepository()
        let useCase = FetchDashboardUseCase(repository: mockRepository)
        let viewModel = HomeViewModel(fetchDashboardUseCase: useCase)

        // When
        await viewModel.loadDashboard()

        // Then
        #expect(viewModel.isLoading == false)
    }

    @Test("loadDashboardエラー時にerrorMessageが設定される")
    func loadDashboardエラー時にerrorMessageが設定される() async throws {
        // Given
        let mockRepository = MockProjectRepository(emptyForTesting: true)
        mockRepository.shouldThrowError = true
        let useCase = FetchDashboardUseCase(repository: mockRepository)
        let viewModel = HomeViewModel(fetchDashboardUseCase: useCase)

        // When
        await viewModel.loadDashboard()

        // Then
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isLoading == false)
    }

    @Test("loadDashboard成功時はerrorMessageがクリアされる")
    func loadDashboard成功時はerrorMessageがクリアされる() async throws {
        // Given
        let mockRepository = MockProjectRepository()
        let useCase = FetchDashboardUseCase(repository: mockRepository)
        let viewModel = HomeViewModel(fetchDashboardUseCase: useCase)

        // 最初にエラー状態にする
        mockRepository.shouldThrowError = true
        await viewModel.loadDashboard()
        #expect(viewModel.errorMessage != nil)

        // When: 成功するロード
        mockRepository.shouldThrowError = false
        await viewModel.loadDashboard()

        // Then: エラーがクリアされる
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - refresh テスト

    @Test("refreshはloadDashboardを呼び出す")
    func refreshはloadDashboardを呼び出す() async throws {
        // Given
        let mockRepository = MockProjectRepository()
        let useCase = FetchDashboardUseCase(repository: mockRepository)
        let viewModel = HomeViewModel(fetchDashboardUseCase: useCase)

        // When
        await viewModel.refresh()

        // Then
        #expect(viewModel.isLoading == false)
    }

    // MARK: - startNewProject テスト

    @Test("startNewProjectでshowChatがtrueになる")
    func startNewProjectでshowChatがtrueになる() async throws {
        // Given
        let mockRepository = MockProjectRepository(emptyForTesting: true)
        let useCase = FetchDashboardUseCase(repository: mockRepository)
        let viewModel = HomeViewModel(fetchDashboardUseCase: useCase)

        // When
        viewModel.startNewProject()

        // Then
        #expect(viewModel.showChat == true)
    }

    // MARK: - dismissChat テスト

    @Test("dismissChatでshowChatがfalseになる")
    func dismissChatでshowChatがfalseになる() async throws {
        // Given
        let mockRepository = MockProjectRepository(emptyForTesting: true)
        let useCase = FetchDashboardUseCase(repository: mockRepository)
        let viewModel = HomeViewModel(fetchDashboardUseCase: useCase)
        viewModel.startNewProject()

        // When
        viewModel.dismissChat()

        // Then
        #expect(viewModel.showChat == false)
    }

    @Test("dismissChatでnewProjectInputがクリアされる")
    func dismissChatでnewProjectInputがクリアされる() async throws {
        // Given
        let mockRepository = MockProjectRepository(emptyForTesting: true)
        let useCase = FetchDashboardUseCase(repository: mockRepository)
        let viewModel = HomeViewModel(fetchDashboardUseCase: useCase)
        viewModel.newProjectInput = "テストプロジェクト"
        viewModel.startNewProject()

        // When
        viewModel.dismissChat()

        // Then
        #expect(viewModel.newProjectInput.isEmpty)
    }

    // MARK: - データ分類テスト

    @Test("進行中プロジェクトが正しく取得される")
    func 進行中プロジェクトが正しく取得される() async throws {
        // Given
        let mockRepository = MockProjectRepository(emptyForTesting: true)
        let template = Template(segments: [
            Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング"),
            Segment(order: 1, startSeconds: 5, endSeconds: 10, segmentDescription: "エンディング")
        ])
        let project = Project(
            name: "テスト進行中",
            template: template,
            videoAssets: [
                VideoAsset(segmentOrder: 0, localFileURL: "mock://video.mp4", duration: 5)
            ],
            status: .recording
        )
        try await mockRepository.save(project)

        let useCase = FetchDashboardUseCase(repository: mockRepository)
        let viewModel = HomeViewModel(fetchDashboardUseCase: useCase)

        // When
        await viewModel.loadDashboard()

        // Then
        #expect(viewModel.inProgressProjects.count == 1)
        #expect(viewModel.inProgressProjects.first?.name == "テスト進行中")
    }

    @Test("完成したプロジェクトが正しく取得される")
    func 完成したプロジェクトが正しく取得される() async throws {
        // Given
        let mockRepository = MockProjectRepository(emptyForTesting: true)
        let project = Project(name: "完成テスト", status: .completed)
        try await mockRepository.save(project)

        let useCase = FetchDashboardUseCase(repository: mockRepository)
        let viewModel = HomeViewModel(fetchDashboardUseCase: useCase)

        // When
        await viewModel.loadDashboard()

        // Then
        #expect(viewModel.completedProjects.count == 1)
        #expect(viewModel.completedProjects.first?.name == "完成テスト")
    }

    @Test("最近のプロジェクトが正しくソートされる")
    func 最近のプロジェクトが正しくソートされる() async throws {
        // Given
        let mockRepository = MockProjectRepository(emptyForTesting: true)
        let now = Date()
        let project1 = Project(name: "古い", status: .recording, updatedAt: now.addingTimeInterval(-3600))
        let project2 = Project(name: "新しい", status: .recording, updatedAt: now)
        try await mockRepository.save(project1)
        try await mockRepository.save(project2)

        let useCase = FetchDashboardUseCase(repository: mockRepository)
        let viewModel = HomeViewModel(fetchDashboardUseCase: useCase)

        // When
        await viewModel.loadDashboard()

        // Then
        #expect(viewModel.recentProjects.count == 2)
        #expect(viewModel.recentProjects.first?.name == "新しい")
    }
}
