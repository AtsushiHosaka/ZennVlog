import SwiftUI

struct HomeView: View {

    // MARK: - Properties

    @State var viewModel: HomeViewModel
    @State private var showErrorAlert: Bool = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    CreateNewCard(
                        inputText: $viewModel.newProjectInput,
                        onSubmit: {
                            viewModel.startNewProject()
                        }
                    )
                    .padding(.horizontal)

                    DashboardSection(
                        title: "進行中のプロジェクト",
                        items: viewModel.inProgressProjects,
                        emptyMessage: "進行中のプロジェクトはありません"
                    ) { project in
                        InProgressProjectCard(project: project)
                    }
                    .padding(.horizontal)

                    DashboardSection(
                        title: "最近のプロジェクト",
                        items: viewModel.recentProjects,
                        emptyMessage: "最近のプロジェクトはありません"
                    ) { project in
                        RecentProjectCard(project: project)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("ホーム")
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadDashboard()
            }
            .overlay {
                if viewModel.isLoading && viewModel.inProgressProjects.isEmpty {
                    ProgressView()
                }
            }
            .onChange(of: viewModel.errorMessage) { _, newValue in
                showErrorAlert = newValue != nil
            }
            .alert("エラー", isPresented: $showErrorAlert) {
                Button("リトライ") {
                    Task {
                        await viewModel.loadDashboard()
                    }
                }
                Button("閉じる", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .fullScreenCover(isPresented: $viewModel.showChat) {
                let coordinator = AppWorkflowCoordinator(container: .shared)
                let chatViewModel = coordinator.makeChatViewModel(
                    initialMessage: viewModel.newProjectInput
                )
                ChatView(viewModel: chatViewModel) { template in
                    Task {
                        await viewModel.handleTemplateConfirmed(template: template)
                    }
                }
            }
            .navigationDestination(isPresented: $viewModel.showRecording) {
                if let project = viewModel.projectForRecording {
                    let coordinator = AppWorkflowCoordinator(container: .shared)
                    RecordingView(viewModel: coordinator.makeRecordingViewModel(project: project))
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let container = DIContainer.preview
    let useCase = FetchDashboardUseCase(repository: container.projectRepository)
    let createProjectUseCase = CreateProjectFromTemplateUseCase(repository: container.projectRepository)
    let viewModel = HomeViewModel(
        fetchDashboardUseCase: useCase,
        createProjectFromTemplateUseCase: createProjectUseCase
    )
    HomeView(viewModel: viewModel)
}

#Preview("空の状態") {
    let repository = MockProjectRepository(emptyForTesting: true)
    let useCase = FetchDashboardUseCase(repository: repository)
    let createProjectUseCase = CreateProjectFromTemplateUseCase(repository: repository)
    let viewModel = HomeViewModel(
        fetchDashboardUseCase: useCase,
        createProjectFromTemplateUseCase: createProjectUseCase
    )
    HomeView(viewModel: viewModel)
}
