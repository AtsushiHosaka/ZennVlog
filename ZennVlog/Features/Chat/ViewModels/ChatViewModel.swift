import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModel {

    // MARK: - Properties

    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    var quickReplies: [String] = []
    var suggestedTemplates: [TemplateDTO] = []
    var selectedTemplate: TemplateDTO?
    var attachedVideoURL: URL?
    var streamingText: String = ""
    var isTemplateConfirmed: Bool = false
    var isAnalyzingVideo: Bool = false
    var toolExecutionStatus: ToolExecutionStatus?

    // MARK: - Computed Properties

    var canStartRecording: Bool {
        selectedTemplate != nil && isTemplateConfirmed
    }

    // MARK: - Dependencies

    private let workflowManager: ChatWorkflowManager
    private let fetchTemplatesUseCase: FetchTemplatesUseCase
    private let analyzeVideoUseCase: AnalyzeVideoUseCase
    private let syncChatHistoryUseCase: SyncChatHistoryUseCase
    private let initializeChatSessionUseCase: InitializeChatSessionUseCase

    // MARK: - Properties

    let projectId: UUID?
    var chatMode: ChatMode?

    // MARK: - Init

    private let initialMessage: String

    init(
        workflowManager: ChatWorkflowManager,
        fetchTemplatesUseCase: FetchTemplatesUseCase,
        analyzeVideoUseCase: AnalyzeVideoUseCase,
        syncChatHistoryUseCase: SyncChatHistoryUseCase,
        initializeChatSessionUseCase: InitializeChatSessionUseCase,
        projectId: UUID? = nil,
        initialMessage: String = "",
        chatMode: ChatMode? = nil
    ) {
        self.workflowManager = workflowManager
        self.fetchTemplatesUseCase = fetchTemplatesUseCase
        self.analyzeVideoUseCase = analyzeVideoUseCase
        self.syncChatHistoryUseCase = syncChatHistoryUseCase
        self.initializeChatSessionUseCase = initializeChatSessionUseCase
        self.projectId = projectId
        self.initialMessage = initialMessage
        self.chatMode = chatMode
    }

    // MARK: - Public Methods

    func sendMessage() async {
        guard !inputText.isEmpty else { return }

        guard let chatMode else {
            quickReplies = ["テンプレートから選ぶ", "オリジナルで作る"]
            return
        }

        let messageText = inputText
        let attachedVideoURLString = attachedVideoURL?.absoluteString
        let attachedVideoURL = attachedVideoURL
        let userMessage = ChatMessage(
            role: .user,
            content: messageText,
            attachedVideoURL: attachedVideoURLString
        )
        // Build history BEFORE appending user message to avoid duplication in contents
        let history = messages.map { msg in
            ChatMessageDTO(
                role: msg.role == .user ? .user : .assistant,
                content: msg.content,
                attachedVideoURL: msg.attachedVideoURL
            )
        }

        messages.append(userMessage)
        await syncMessage(userMessage)
        inputText = ""
        isLoading = true
        quickReplies = []
        self.attachedVideoURL = nil

        do {
            let response = try await workflowManager.sendMessage(
                message: messageText,
                history: history,
                attachedVideoURL: attachedVideoURL,
                projectId: projectId,
                chatMode: chatMode,
                onToolExecution: { [weak self] status in
                    guard let self else { return }
                    self.toolExecutionStatus = status
                    if status.toolName == "videoSummary" || status.toolName == "videoAnalysis" {
                        self.isAnalyzingVideo = status.state == .executing
                    }
                    if status.state == .executing {
                        let hint = self.toolHintMessage(for: status.toolName)
                        let hintMessage = ChatMessage(role: .assistant, content: hint)
                        self.messages.append(hintMessage)
                    }
                }
            )

            let assistantMessage = ChatMessage(role: .assistant, content: response.text)
            messages.append(assistantMessage)
            await syncMessage(assistantMessage)

            if !response.suggestedTemplates.isEmpty {
                suggestedTemplates = response.suggestedTemplates
                selectedTemplate = nil
                quickReplies = ["オリジナルで作る"]
            } else {
                quickReplies = response.quickReplies
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
        toolExecutionStatus = nil
        isAnalyzingVideo = false
    }

    func confirmTemplate() {
        guard selectedTemplate != nil else { return }
        isTemplateConfirmed = true
    }

    func sendQuickReply(_ reply: String) async {
        switch reply {
        case "テンプレートから選ぶ":
            chatMode = .templateSelection
            quickReplies = []
            await appendUserOperationMessage(reply)
            inputText = initialMessage
            await sendMessage()
        case "オリジナルで作る":
            chatMode = .customCreation
            quickReplies = []
            suggestedTemplates = []
            selectedTemplate = nil
            await appendUserOperationMessage(reply)
            inputText = initialMessage
            await sendMessage()
        case "このテンプレートを使う":
            guard selectedTemplate != nil else { return }
            isTemplateConfirmed = true
            quickReplies = []
            await appendUserOperationMessage(reply)
        default:
            inputText = reply
            await sendMessage()
        }
    }

    func selectTemplate(_ template: TemplateDTO) {
        selectedTemplate = template
    }

    func attachVideo(_ url: URL) {
        attachedVideoURL = url
    }

    func removeAttachedVideo() {
        attachedVideoURL = nil
    }

    func clearError() {
        errorMessage = nil
    }

    func reset() {
        inputText = ""
        errorMessage = nil
        attachedVideoURL = nil
        streamingText = ""
        quickReplies = []
        suggestedTemplates = []
        isTemplateConfirmed = false
        isAnalyzingVideo = false
        toolExecutionStatus = nil
        chatMode = nil
    }

    func startConversation() async {
        guard messages.isEmpty, !initialMessage.isEmpty else { return }

        let greeting = "「\(initialMessage)」のVlog、いいですね！どちらの方法で作りますか？"
        let assistantMessage = ChatMessage(role: .assistant, content: greeting)
        messages.append(assistantMessage)
        await syncMessage(assistantMessage)
        quickReplies = ["テンプレートから選ぶ", "オリジナルで作る"]
    }

    // MARK: - Private Methods

    private func syncMessage(_ message: ChatMessage) async {
        guard let projectId else { return }
        do {
            try await syncChatHistoryUseCase.execute(projectId: projectId, message: message)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func appendUserOperationMessage(_ text: String) async {
        let message = ChatMessage(role: .user, content: text)
        messages.append(message)
        await syncMessage(message)
    }

    private func toolHintMessage(for toolName: String) -> String {
        switch toolName {
        case "templateSearch":
            return "ぴったりのテンプレートを探してみますね！"
        case "videoSummary", "videoAnalysis":
            return "動画を分析してみますね！"
        case "generateCustomTemplate":
            return "オリジナルテンプレートを作成しますね！"
        default:
            return "少々お待ちください..."
        }
    }

}
