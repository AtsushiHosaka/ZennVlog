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

    private let sendMessageUseCase: SendMessageWithAIUseCase
    private let fetchTemplatesUseCase: FetchTemplatesUseCase
    private let analyzeVideoUseCase: AnalyzeVideoUseCase
    private let syncChatHistoryUseCase: SyncChatHistoryUseCase
    private let initializeChatSessionUseCase: InitializeChatSessionUseCase

    // MARK: - Properties

    let projectId: UUID?

    // MARK: - Init

    private let initialMessage: String

    init(
        sendMessageUseCase: SendMessageWithAIUseCase,
        fetchTemplatesUseCase: FetchTemplatesUseCase,
        analyzeVideoUseCase: AnalyzeVideoUseCase,
        syncChatHistoryUseCase: SyncChatHistoryUseCase,
        initializeChatSessionUseCase: InitializeChatSessionUseCase,
        projectId: UUID? = nil,
        initialMessage: String = ""
    ) {
        self.sendMessageUseCase = sendMessageUseCase
        self.fetchTemplatesUseCase = fetchTemplatesUseCase
        self.analyzeVideoUseCase = analyzeVideoUseCase
        self.syncChatHistoryUseCase = syncChatHistoryUseCase
        self.initializeChatSessionUseCase = initializeChatSessionUseCase
        self.projectId = projectId
        self.initialMessage = initialMessage
    }

    // MARK: - Public Methods

    func sendMessage() async {
        guard !inputText.isEmpty else { return }

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
        var shouldAnalyzeAttachedVideo = false

        do {
            let response = try await sendMessageUseCase.execute(
                message: messageText,
                history: history,
                onToolExecution: { [weak self] status in
                    guard let self else { return }
                    self.toolExecutionStatus = status
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
                quickReplies = []
            } else {
                updateQuickReplies(from: response.text)
            }
            shouldAnalyzeAttachedVideo = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
        toolExecutionStatus = nil

        if shouldAnalyzeAttachedVideo, let attachedVideoURL {
            Task {
                await analyzeAttachedVideoInBackground(attachedVideoURL)
            }
        }
    }

    func confirmTemplate() {
        guard selectedTemplate != nil else { return }
        isTemplateConfirmed = true
    }

    func sendQuickReply(_ reply: String) async {
        switch reply {
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
    }

    func startConversation() async {
        guard messages.isEmpty, !initialMessage.isEmpty else { return }

        inputText = initialMessage
        await sendMessage()
    }

    // MARK: - Private Methods

    private func syncMessage(_ message: ChatMessage) async {
        guard let projectId else { return }
        try? await syncChatHistoryUseCase.execute(projectId: projectId, message: message)
    }

    private func appendUserOperationMessage(_ text: String) async {
        let message = ChatMessage(role: .user, content: text)
        messages.append(message)
        await syncMessage(message)
    }

    private func analyzeAttachedVideoInBackground(_ url: URL) async {
        guard !isAnalyzingVideo else { return }
        isAnalyzingVideo = true
        defer { isAnalyzingVideo = false }

        do {
            let result = try await analyzeVideoUseCase.execute(videoURL: url)
            let summary = makeVideoAnalysisSummary(result)
            let assistantMessage = ChatMessage(role: .assistant, content: summary)
            messages.append(assistantMessage)
            await syncMessage(assistantMessage)
        } catch {
            errorMessage = "動画解析に失敗しました: \(error.localizedDescription)"
        }
    }

    private func makeVideoAnalysisSummary(_ result: VideoAnalysisResult) -> String {
        guard !result.segments.isEmpty else {
            return "動画を解析しました。大きなシーン分割は検出できませんでした。"
        }

        let lines = result.segments.prefix(3).enumerated().map { index, segment in
            "\(index + 1). \(Int(segment.startSeconds))s-\(Int(segment.endSeconds))s: \(segment.description)"
        }

        return """
        動画の解析が完了しました。主なシーンは次の通りです。
        \(lines.joined(separator: "\n"))
        """
    }

    private func toolHintMessage(for toolName: String) -> String {
        switch toolName {
        case "templateSearch":
            return "ぴったりのテンプレートを探してみますね！"
        case "videoAnalysis":
            return "動画を分析してみますね！"
        default:
            return "少々お待ちください..."
        }
    }

    private func updateQuickReplies(from responseText: String) {
        let text = responseText.lowercased()

        if text.contains("よろしいですか") || text.contains("いかがでしょうか") || text.contains("どうですか") {
            quickReplies = ["はい", "いいえ"]
        } else if text.contains("テーマ") || text.contains("どんな") {
            quickReplies = ["日常", "旅行", "グルメ", "趣味"]
        } else if text.contains("構成") || text.contains("テンプレート") {
            quickReplies = ["提案してください", "自分で決める"]
        } else {
            quickReplies = []
        }
    }
}
