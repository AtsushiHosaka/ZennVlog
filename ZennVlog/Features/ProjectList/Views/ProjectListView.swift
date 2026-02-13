import SwiftUI

/// 全プロジェクトのリスト表示画面
struct ProjectListView: View {
    @State var viewModel: ProjectListViewModel
    @State private var showChat = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if let errorMessage = viewModel.errorMessage {
                    errorView(message: errorMessage)
                } else if viewModel.projects.isEmpty {
                    emptyView
                } else {
                    projectList
                }
            }
            .navigationTitle("プロジェクト")
            .refreshable {
                await viewModel.refresh()
            }
            .fullScreenCover(isPresented: $showChat) {
                let container = DIContainer.shared
                let chatViewModel = ChatViewModel(
                    sendMessageUseCase: SendMessageWithAIUseCase(
                        repository: container.geminiRepository,
                        templateRepository: container.templateRepository
                    ),
                    fetchTemplatesUseCase: FetchTemplatesUseCase(repository: container.templateRepository),
                    analyzeVideoUseCase: AnalyzeVideoUseCase(repository: container.geminiRepository),
                    syncChatHistoryUseCase: SyncChatHistoryUseCase(),
                    initializeChatSessionUseCase: InitializeChatSessionUseCase()
                )
                ChatView(viewModel: chatViewModel) { template in
                    Task {
                        await viewModel.handleTemplateConfirmed(template: template)
                        showChat = false
                    }
                }
            }
            .navigationDestination(isPresented: $viewModel.showRecording) {
                if let project = viewModel.projectForRecording {
                    let container = DIContainer.shared
                    RecordingView(viewModel: RecordingViewModel(
                        project: project,
                        saveVideoAssetUseCase: SaveVideoAssetUseCase(repository: container.projectRepository),
                        generateGuideImageUseCase: GenerateGuideImageUseCase(repository: container.imagenRepository),
                        analyzeVideoUseCase: AnalyzeVideoUseCase(repository: container.geminiRepository),
                        trimVideoUseCase: TrimVideoUseCase(),
                        deleteVideoAssetUseCase: DeleteVideoAssetUseCase(repository: container.projectRepository)
                    ))
                }
            }
        }
        .task {
            await viewModel.loadProjects()
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("読み込み中...")
                .foregroundColor(.secondary)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("再試行") {
                Task {
                    await viewModel.loadProjects()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("プロジェクトがありません")
                .font(.headline)

            Text("新しいプロジェクトを作成して\nVlogを始めましょう")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showChat = true
            } label: {
                Label("新しいプロジェクトを作成", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var projectList: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.projects, id: \.id) { project in
                    NavigationLink {
                        let container = DIContainer.shared
                        let recordingViewModel = RecordingViewModel(
                            project: project,
                            saveVideoAssetUseCase: SaveVideoAssetUseCase(repository: container.projectRepository),
                            generateGuideImageUseCase: GenerateGuideImageUseCase(repository: container.imagenRepository),
                            analyzeVideoUseCase: AnalyzeVideoUseCase(repository: container.geminiRepository),
                            trimVideoUseCase: TrimVideoUseCase(),
                            deleteVideoAssetUseCase: DeleteVideoAssetUseCase(repository: container.projectRepository)
                        )
                        RecordingView(viewModel: recordingViewModel)
                    } label: {
                        ProjectCard(project: project)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}

// MARK: - Previews

#Preview("プロジェクトあり") {
    let container = DIContainer.preview
    let useCase = FetchProjectsUseCase(repository: container.projectRepository)
    let createProjectUseCase = CreateProjectFromTemplateUseCase(repository: container.projectRepository)
    let viewModel = ProjectListViewModel(
        fetchProjectsUseCase: useCase,
        createProjectFromTemplateUseCase: createProjectUseCase
    )
    return ProjectListView(viewModel: viewModel)
}

#Preview("空状態") {
    // 空のリポジトリを使用
    let viewModel = ProjectListViewModel(
        fetchProjectsUseCase: FetchProjectsUseCase(repository: MockProjectRepository(emptyForTesting: true)),
        createProjectFromTemplateUseCase: CreateProjectFromTemplateUseCase(
            repository: MockProjectRepository(emptyForTesting: true)
        )
    )
    return ProjectListView(viewModel: viewModel)
}

#Preview("ローディング") {
    let viewModel = ProjectListViewModel(
        fetchProjectsUseCase: FetchProjectsUseCase(repository: MockProjectRepository()),
        createProjectFromTemplateUseCase: CreateProjectFromTemplateUseCase(
            repository: MockProjectRepository()
        )
    )
    viewModel.isLoading = true
    return ProjectListView(viewModel: viewModel)
}

#Preview("エラー状態") {
    let viewModel = ProjectListViewModel(
        fetchProjectsUseCase: FetchProjectsUseCase(repository: MockProjectRepository()),
        createProjectFromTemplateUseCase: CreateProjectFromTemplateUseCase(
            repository: MockProjectRepository()
        )
    )
    viewModel.errorMessage = "ネットワークエラーが発生しました"
    return ProjectListView(viewModel: viewModel)
}
