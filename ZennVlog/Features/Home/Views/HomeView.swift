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
                let container = DIContainer.shared
                let chatViewModel = ChatViewModel(
                    sendMessageUseCase: SendMessageWithAIUseCase(repository: container.geminiRepository),
                    fetchTemplatesUseCase: FetchTemplatesUseCase(repository: container.templateRepository),
                    analyzeVideoUseCase: AnalyzeVideoUseCase(repository: container.geminiRepository),
                    syncChatHistoryUseCase: SyncChatHistoryUseCase(),
                    initializeChatSessionUseCase: InitializeChatSessionUseCase()
                )
                ChatView(viewModel: chatViewModel) { _, _ in
                    viewModel.dismissChat()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let container = DIContainer.preview
    let useCase = FetchDashboardUseCase(repository: container.projectRepository)
    let viewModel = HomeViewModel(fetchDashboardUseCase: useCase)
    return HomeView(viewModel: viewModel)
}

#Preview("空の状態") {
    let repository = MockProjectRepository(emptyForTesting: true)
    let useCase = FetchDashboardUseCase(repository: repository)
    let viewModel = HomeViewModel(fetchDashboardUseCase: useCase)
    return HomeView(viewModel: viewModel)
}
