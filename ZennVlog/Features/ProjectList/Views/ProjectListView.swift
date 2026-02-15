import SwiftUI

/// 全プロジェクトのリスト表示画面
struct ProjectListView: View {
    @State var viewModel: ProjectListViewModel
    @State private var showChat = false
    @State private var showDeleteAllConfirmation = false

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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showDeleteAllConfirmation = true
                        } label: {
                            Label("全プロジェクト削除", systemImage: "trash")
                        }
                        .disabled(viewModel.projects.isEmpty || viewModel.isDeletingAllProjects || viewModel.isLoading)
                    } label: {
                        if viewModel.isDeletingAllProjects {
                            ProgressView()
                        } else {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .fullScreenCover(isPresented: $showChat) {
                let coordinator = AppWorkflowCoordinator(container: .shared)
                let chatViewModel = coordinator.makeChatViewModel()
                ChatView(viewModel: chatViewModel) { template in
                    Task {
                        await viewModel.handleTemplateConfirmed(template: template)
                        showChat = false
                    }
                }
            }
            .navigationDestination(isPresented: $viewModel.showRecording) {
                if let project = viewModel.projectForRecording {
                    let coordinator = AppWorkflowCoordinator(container: .shared)
                    RecordingView(viewModel: coordinator.makeRecordingViewModel(project: project))
                }
            }
            .alert("全プロジェクトを削除しますか？", isPresented: $showDeleteAllConfirmation) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {
                    Task {
                        await viewModel.deleteAllProjects()
                    }
                }
            } message: {
                Text("この操作は元に戻せません。プロジェクト情報のみ削除され、ローカル動画ファイルは保持されます。")
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
                        let coordinator = AppWorkflowCoordinator(container: .shared)
                        RecordingView(viewModel: coordinator.makeRecordingViewModel(project: project))
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
    let deleteAllUseCase = DeleteAllProjectsUseCase(repository: container.projectRepository)
    let viewModel = ProjectListViewModel(
        fetchProjectsUseCase: useCase,
        createProjectFromTemplateUseCase: createProjectUseCase,
        deleteAllProjectsUseCase: deleteAllUseCase
    )
    ProjectListView(viewModel: viewModel)
}

#Preview("空状態") {
    // 空のリポジトリを使用
    let viewModel = ProjectListViewModel(
        fetchProjectsUseCase: FetchProjectsUseCase(repository: MockProjectRepository(emptyForTesting: true)),
        createProjectFromTemplateUseCase: CreateProjectFromTemplateUseCase(
            repository: MockProjectRepository(emptyForTesting: true)
        ),
        deleteAllProjectsUseCase: DeleteAllProjectsUseCase(
            repository: MockProjectRepository(emptyForTesting: true)
        )
    )
    ProjectListView(viewModel: viewModel)
}

#Preview("ローディング") {
    let viewModel: ProjectListViewModel = {
        let viewModel = ProjectListViewModel(
            fetchProjectsUseCase: FetchProjectsUseCase(repository: MockProjectRepository()),
            createProjectFromTemplateUseCase: CreateProjectFromTemplateUseCase(
                repository: MockProjectRepository()
            ),
            deleteAllProjectsUseCase: DeleteAllProjectsUseCase(
                repository: MockProjectRepository()
            )
        )
        viewModel.isLoading = true
        return viewModel
    }()
    ProjectListView(viewModel: viewModel)
}

#Preview("エラー状態") {
    let viewModel: ProjectListViewModel = {
        let viewModel = ProjectListViewModel(
            fetchProjectsUseCase: FetchProjectsUseCase(repository: MockProjectRepository()),
            createProjectFromTemplateUseCase: CreateProjectFromTemplateUseCase(
                repository: MockProjectRepository()
            ),
            deleteAllProjectsUseCase: DeleteAllProjectsUseCase(
                repository: MockProjectRepository()
            )
        )
        viewModel.errorMessage = "ネットワークエラーが発生しました"
        return viewModel
    }()
    ProjectListView(viewModel: viewModel)
}
