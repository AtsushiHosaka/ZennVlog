import Foundation
import Testing
@testable import ZennVlog

@Suite("ProjectListViewModel Tests")
@MainActor
struct ProjectListViewModelTests {

    // MARK: - 初期化のテスト

    @Test("初期状態が正しい")
    func viewModelHasCorrectInitialState() {
        // Given
        let mockRepository = MockProjectRepository()
        let useCase = FetchProjectsUseCase(repository: mockRepository)
        let createProjectUseCase = CreateProjectFromTemplateUseCase(repository: mockRepository)
        let viewModel = ProjectListViewModel(fetchProjectsUseCase: useCase, createProjectFromTemplateUseCase: createProjectUseCase)

        // Then
        #expect(viewModel.projects.isEmpty)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - ローディング状態のテスト

    @Test("ローディング状態が正しく遷移する")
    func loadProjectsTransitionsLoadingState() async {
        // Given
        let mockRepository = MockProjectRepository()
        let useCase = FetchProjectsUseCase(repository: mockRepository)
        let createProjectUseCase = CreateProjectFromTemplateUseCase(repository: mockRepository)
        let viewModel = ProjectListViewModel(fetchProjectsUseCase: useCase, createProjectFromTemplateUseCase: createProjectUseCase)

        // Then: 初期状態ではローディングしていない
        #expect(!viewModel.isLoading)

        // When: loadProjectsを呼び出す
        async let loadTask: () = viewModel.loadProjects()

        // 短い待機でローディング状態を確認
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Then: 完了後はローディング終了
        await loadTask
        #expect(!viewModel.isLoading)
    }

    @Test("成功時にプロジェクトを設定する")
    func loadProjectsPopulatesProjectsOnSuccess() async {
        // Given
        let mockRepository = MockProjectRepository()
        let useCase = FetchProjectsUseCase(repository: mockRepository)
        let createProjectUseCase = CreateProjectFromTemplateUseCase(repository: mockRepository)
        let viewModel = ProjectListViewModel(fetchProjectsUseCase: useCase, createProjectFromTemplateUseCase: createProjectUseCase)

        // When
        await viewModel.loadProjects()

        // Then
        #expect(viewModel.projects.count == 2)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.projects[0].name == "週末のお出かけVlog")
    }

    @Test("空の結果でも正常動作する")
    func loadProjectsHandlesEmptyResults() async {
        // Given
        let mockRepository = MockProjectRepository()
        let allProjects = try? await mockRepository.fetchAll()
        if let allProjects = allProjects {
            for project in allProjects {
                try? await mockRepository.delete(project)
            }
        }
        let useCase = FetchProjectsUseCase(repository: mockRepository)
        let createProjectUseCase = CreateProjectFromTemplateUseCase(repository: mockRepository)
        let viewModel = ProjectListViewModel(fetchProjectsUseCase: useCase, createProjectFromTemplateUseCase: createProjectUseCase)

        // When
        await viewModel.loadProjects()

        // Then
        #expect(viewModel.projects.isEmpty)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - エラー状態のテスト

    @Test("エラー時にメッセージを設定する")
    func loadProjectsSetsErrorMessageOnFailure() async {
        // Given
        let mockRepository = MockProjectRepository()
        mockRepository.shouldThrowError = true
        let useCase = FetchProjectsUseCase(repository: mockRepository)
        let createProjectUseCase = CreateProjectFromTemplateUseCase(repository: mockRepository)
        let viewModel = ProjectListViewModel(fetchProjectsUseCase: useCase, createProjectFromTemplateUseCase: createProjectUseCase)

        // When
        await viewModel.loadProjects()

        // Then
        #expect(viewModel.errorMessage != nil)
        #expect(!viewModel.isLoading)
        #expect(viewModel.projects.isEmpty)
    }

    @Test("エラー後に再試行で回復する")
    func loadProjectsRecoversAfterError() async {
        // Given
        let mockRepository = MockProjectRepository()
        mockRepository.shouldThrowError = true
        let useCase = FetchProjectsUseCase(repository: mockRepository)
        let createProjectUseCase = CreateProjectFromTemplateUseCase(repository: mockRepository)
        let viewModel = ProjectListViewModel(fetchProjectsUseCase: useCase, createProjectFromTemplateUseCase: createProjectUseCase)

        // When: 最初はエラー
        await viewModel.loadProjects()
        #expect(viewModel.errorMessage != nil)

        // Then: エラーフラグを解除して再試行
        mockRepository.shouldThrowError = false
        await viewModel.loadProjects()

        // Then: 成功して回復
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.projects.count == 2)
        #expect(!viewModel.isLoading)
    }

    @Test("エラーメッセージが日本語で設定される")
    func loadProjectsSetsJapaneseErrorMessage() async {
        // Given
        let mockRepository = MockProjectRepository()
        mockRepository.shouldThrowError = true
        let useCase = FetchProjectsUseCase(repository: mockRepository)
        let createProjectUseCase = CreateProjectFromTemplateUseCase(repository: mockRepository)
        let viewModel = ProjectListViewModel(fetchProjectsUseCase: useCase, createProjectFromTemplateUseCase: createProjectUseCase)

        // When
        await viewModel.loadProjects()

        // Then
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("プロジェクトの取得に失敗しました") == true)
    }

    // MARK: - リフレッシュロジックのテスト

    @Test("既存データをクリアして再取得する")
    func refreshReloadsData() async {
        // Given
        let mockRepository = MockProjectRepository()
        let useCase = FetchProjectsUseCase(repository: mockRepository)
        let createProjectUseCase = CreateProjectFromTemplateUseCase(repository: mockRepository)
        let viewModel = ProjectListViewModel(fetchProjectsUseCase: useCase, createProjectFromTemplateUseCase: createProjectUseCase)

        // When: 最初のロード
        await viewModel.loadProjects()
        let initialCount = viewModel.projects.count
        #expect(initialCount == 2)

        // リポジトリにプロジェクトを追加
        let newProject = Project(
            name: "新しいVlog",
            theme: "テスト",
            status: .recording
        )
        try? await mockRepository.save(newProject)

        // When: リフレッシュ
        await viewModel.refresh()

        // Then: 新しいデータが反映される
        #expect(viewModel.projects.count == 3)
        #expect(!viewModel.isLoading)
    }

    @Test("エラー状態をクリアする")
    func refreshClearsErrorState() async {
        // Given
        let mockRepository = MockProjectRepository()
        mockRepository.shouldThrowError = true
        let useCase = FetchProjectsUseCase(repository: mockRepository)
        let createProjectUseCase = CreateProjectFromTemplateUseCase(repository: mockRepository)
        let viewModel = ProjectListViewModel(fetchProjectsUseCase: useCase, createProjectFromTemplateUseCase: createProjectUseCase)

        // When: エラー状態にする
        await viewModel.loadProjects()
        #expect(viewModel.errorMessage != nil)

        // エラーフラグを解除してリフレッシュ
        mockRepository.shouldThrowError = false
        await viewModel.refresh()

        // Then: エラーがクリアされる
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.projects.count == 2)
    }

    // MARK: - 統合テスト

    @Test("UseCaseと統合して正しく動作する")
    func loadProjectsIntegratesWithUseCase() async {
        // Given
        let mockRepository = MockProjectRepository()
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)

        let recentProject = Project(
            name: "最新プロジェクト",
            theme: "テスト",
            status: .recording,
            updatedAt: now
        )
        let oldProject = Project(
            name: "古いプロジェクト",
            theme: "テスト",
            status: .completed,
            updatedAt: yesterday
        )

        try? await mockRepository.save(recentProject)
        try? await mockRepository.save(oldProject)

        let useCase = FetchProjectsUseCase(repository: mockRepository)
        let createProjectUseCase = CreateProjectFromTemplateUseCase(repository: mockRepository)
        let viewModel = ProjectListViewModel(fetchProjectsUseCase: useCase, createProjectFromTemplateUseCase: createProjectUseCase)

        // When
        await viewModel.loadProjects()

        // Then: UseCaseのソート機能が正しく適用される
        #expect(viewModel.projects.count >= 2)
        #expect(viewModel.projects[0].name == "最新プロジェクト")
        #expect(viewModel.projects[0].updatedAt > viewModel.projects[1].updatedAt)
    }

    @Test("連続呼び出しでも正しく動作する")
    func loadProjectsHandlesConsecutiveCalls() async {
        // Given
        let mockRepository = MockProjectRepository()
        let useCase = FetchProjectsUseCase(repository: mockRepository)
        let createProjectUseCase = CreateProjectFromTemplateUseCase(repository: mockRepository)
        let viewModel = ProjectListViewModel(fetchProjectsUseCase: useCase, createProjectFromTemplateUseCase: createProjectUseCase)

        // When: 複数回連続で呼び出す
        await viewModel.loadProjects()
        let firstCount = viewModel.projects.count

        await viewModel.loadProjects()
        let secondCount = viewModel.projects.count

        await viewModel.loadProjects()
        let thirdCount = viewModel.projects.count

        // Then: すべて同じ結果が返る
        #expect(firstCount == 2)
        #expect(secondCount == 2)
        #expect(thirdCount == 2)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("異なるステータスのプロジェクトが混在する")
    func loadProjectsHandlesMixedStatuses() async {
        // Given
        let mockRepository = MockProjectRepository()
        let now = Date()

        let chattingProject = Project(
            name: "チャット中プロジェクト",
            theme: "テスト",
            status: .chatting,
            updatedAt: now
        )
        let recordingProject = Project(
            name: "録画中プロジェクト",
            theme: "テスト",
            status: .recording,
            updatedAt: now.addingTimeInterval(-3600)
        )
        let editingProject = Project(
            name: "編集中プロジェクト",
            theme: "テスト",
            status: .editing,
            updatedAt: now.addingTimeInterval(-7200)
        )
        let completedProject = Project(
            name: "完了プロジェクト",
            theme: "テスト",
            status: .completed,
            updatedAt: now.addingTimeInterval(-10800)
        )

        try? await mockRepository.save(chattingProject)
        try? await mockRepository.save(recordingProject)
        try? await mockRepository.save(editingProject)
        try? await mockRepository.save(completedProject)

        let useCase = FetchProjectsUseCase(repository: mockRepository)
        let createProjectUseCase = CreateProjectFromTemplateUseCase(repository: mockRepository)
        let viewModel = ProjectListViewModel(fetchProjectsUseCase: useCase, createProjectFromTemplateUseCase: createProjectUseCase)

        // When
        await viewModel.loadProjects()

        // Then: すべてのステータスが含まれる
        #expect(viewModel.projects.count >= 4)
        let statuses = viewModel.projects.map { $0.status }
        #expect(statuses.contains(.chatting))
        #expect(statuses.contains(.recording))
        #expect(statuses.contains(.editing))
        #expect(statuses.contains(.completed))
    }
}
