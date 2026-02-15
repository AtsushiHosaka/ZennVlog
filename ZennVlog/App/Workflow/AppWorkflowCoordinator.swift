import Foundation
import Observation

@MainActor
@Observable
final class AppWorkflowCoordinator {
    let container: DIContainer
    let lifecycleManager: ProjectLifecycleManager

    init(container: DIContainer = .shared) {
        self.container = container
        self.lifecycleManager = ProjectLifecycleManager(repository: container.projectRepository)
    }

    func makeChatViewModel(
        projectId: UUID? = nil,
        initialMessage: String = "",
        chatMode: ChatMode? = nil
    ) -> ChatViewModel {
        let sendMessageUseCase = SendMessageWithAIUseCase(
            repository: container.geminiRepository,
            templateRepository: container.templateRepository
        )
        let chatWorkflowManager = ChatWorkflowManager(
            sendMessageUseCase: sendMessageUseCase,
            saveVideoAnalysisSessionUseCase: SaveVideoAnalysisSessionUseCase(
                repository: container.projectRepository
            )
        )
        return ChatViewModel(
            workflowManager: chatWorkflowManager,
            fetchTemplatesUseCase: FetchTemplatesUseCase(repository: container.templateRepository),
            analyzeVideoUseCase: AnalyzeVideoUseCase(repository: container.geminiRepository),
            syncChatHistoryUseCase: SyncChatHistoryUseCase(repository: container.projectRepository),
            initializeChatSessionUseCase: InitializeChatSessionUseCase(),
            projectId: projectId,
            initialMessage: initialMessage,
            chatMode: chatMode
        )
    }

    func makeRecordingViewModel(project: Project) -> RecordingViewModel {
        let workflowManager = RecordingWorkflowManager(
            lifecycleManager: lifecycleManager
        )
        return RecordingViewModel(
            project: project,
            saveVideoAssetUseCase: SaveVideoAssetUseCase(
                repository: container.projectRepository,
                localVideoStorage: container.localVideoStorage
            ),
            generateGuideImageUseCase: GenerateGuideImageUseCase(repository: container.imagenRepository),
            analyzeVideoUseCase: AnalyzeVideoUseCase(repository: container.geminiRepository),
            trimVideoUseCase: TrimVideoUseCase(),
            deleteVideoAssetUseCase: DeleteVideoAssetUseCase(
                repository: container.projectRepository,
                localVideoStorage: container.localVideoStorage
            ),
            photoLibraryService: container.photoLibraryService,
            localVideoStorage: container.localVideoStorage,
            workflowManager: workflowManager
        )
    }

    func makePreviewViewModel(project: Project) -> PreviewViewModel {
        let workflowManager = PreviewWorkflowManager(
            lifecycleManager: lifecycleManager
        )
        return PreviewViewModel(
            project: project,
            exportVideoUseCase: ExportVideoUseCase(repository: container.projectRepository),
            fetchBGMTracksUseCase: FetchBGMTracksUseCase(repository: container.bgmRepository),
            saveSubtitleUseCase: SaveSubtitleUseCase(repository: container.projectRepository),
            deleteSubtitleUseCase: DeleteSubtitleUseCase(repository: container.projectRepository),
            saveBGMSettingsUseCase: SaveBGMSettingsUseCase(repository: container.projectRepository),
            downloadBGMUseCase: DownloadBGMUseCase(repository: container.bgmRepository),
            updateSubtitlePositionUseCase: UpdateSubtitlePositionUseCase(repository: container.projectRepository),
            recoverVideoAssetsUseCase: RecoverVideoAssetsUseCase(
                repository: container.projectRepository,
                photoLibraryService: container.photoLibraryService,
                localVideoStorage: container.localVideoStorage
            ),
            workflowManager: workflowManager
        )
    }

    func makeShareViewModel(project: Project, exportedVideoURL: URL) -> ShareViewModel {
        ShareViewModel(
            project: project,
            exportedVideoURL: exportedVideoURL,
            photoLibrary: container.photoLibraryService,
            activityController: container.activityControllerService
        )
    }
}
