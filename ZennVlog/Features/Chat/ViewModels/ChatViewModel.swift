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
    var selectedTemplate: TemplateDTO?
    var selectedBGM: BGMTrack?
    var attachedVideoURL: URL?
    var streamingText: String = ""
    var isTemplateConfirmed: Bool = false

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

    init(
        sendMessageUseCase: SendMessageWithAIUseCase,
        fetchTemplatesUseCase: FetchTemplatesUseCase,
        analyzeVideoUseCase: AnalyzeVideoUseCase,
        syncChatHistoryUseCase: SyncChatHistoryUseCase,
        initializeChatSessionUseCase: InitializeChatSessionUseCase,
        projectId: UUID? = nil
    ) {
        self.sendMessageUseCase = sendMessageUseCase
        self.fetchTemplatesUseCase = fetchTemplatesUseCase
        self.analyzeVideoUseCase = analyzeVideoUseCase
        self.syncChatHistoryUseCase = syncChatHistoryUseCase
        self.initializeChatSessionUseCase = initializeChatSessionUseCase
        self.projectId = projectId
    }

    // MARK: - Public Methods

    func sendMessage() async {
        guard !inputText.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: inputText)
        messages.append(userMessage)
        await syncMessage(userMessage)

        let messageText = inputText
        inputText = ""
        isLoading = true
        quickReplies = []

        do {
            let history = messages.map { msg in
                ChatMessageDTO(
                    role: msg.role == .user ? .user : .assistant,
                    content: msg.content,
                    attachedVideoURL: msg.attachedVideoURL
                )
            }
            let response = try await sendMessageUseCase.execute(message: messageText, history: history)

            let assistantMessage = ChatMessage(role: .assistant, content: response.text)
            messages.append(assistantMessage)
            await syncMessage(assistantMessage)

            if let template = response.suggestedTemplate {
                selectedTemplate = template
                quickReplies = ["このテンプレートを使う", "他のテンプレートを見る"]
            } else if let bgm = response.suggestedBGM {
                selectedBGM = bgm
                quickReplies = ["このBGMを使う", "他のBGMを見る"]
            } else {
                updateQuickReplies(from: response.text)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func confirmTemplate() {
        guard selectedTemplate != nil else { return }
        isTemplateConfirmed = true
    }

    func sendQuickReply(_ reply: String) async {
        inputText = reply
        await sendMessage()
    }

    func selectTemplate(_ template: TemplateDTO) {
        selectedTemplate = template
    }

    func selectBGM(_ bgm: BGMTrack) {
        selectedBGM = bgm
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
        isTemplateConfirmed = false
    }

    func startConversation() async {
        guard messages.isEmpty else { return }

        isLoading = true

        do {
            let response = try await sendMessageUseCase.execute(message: "こんにちは", history: [])
            let assistantMessage = ChatMessage(role: .assistant, content: response.text)
            messages.append(assistantMessage)
            await syncMessage(assistantMessage)
            updateQuickReplies(from: response.text)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Private Methods

    private func syncMessage(_ message: ChatMessage) async {
        guard let projectId else { return }
        try? await syncChatHistoryUseCase.execute(projectId: projectId, message: message)
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
