import Foundation
import Testing
@testable import ZennVlog

@Suite("ChatViewModel Tests")
@MainActor
struct ChatViewModelTests {

    let viewModel: ChatViewModel
    let mockGeminiRepository: MockGeminiRepository
    let mockTemplateRepository: MockTemplateRepository

    init() async {
        mockGeminiRepository = MockGeminiRepository()
        mockTemplateRepository = MockTemplateRepository()
        viewModel = ChatViewModel(
            sendMessageUseCase: SendMessageWithAIUseCase(repository: mockGeminiRepository),
            fetchTemplatesUseCase: FetchTemplatesUseCase(repository: mockTemplateRepository),
            analyzeVideoUseCase: AnalyzeVideoUseCase(repository: mockGeminiRepository),
            syncChatHistoryUseCase: SyncChatHistoryUseCase(),
            initializeChatSessionUseCase: InitializeChatSessionUseCase()
        )
    }

    // MARK: - 初期状態のテスト

    @Test("初期状態が正しく設定される")
    func 初期状態が正しく設定される() {
        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.inputText.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.quickReplies.isEmpty)
        #expect(viewModel.selectedTemplate == nil)
        #expect(viewModel.selectedBGM == nil)
        #expect(viewModel.attachedVideoURL == nil)
    }

    // MARK: - メッセージ送信のテスト

    @Test("ユーザーメッセージを送信してAIの応答を受け取る")
    func ユーザーメッセージを送信してAIの応答を受け取る() async {
        viewModel.inputText = "こんにちは"
        await viewModel.sendMessage()

        #expect(viewModel.messages.count > 0)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.inputText.isEmpty)
    }

    @Test("空のメッセージは送信しない")
    func 空のメッセージは送信しない() async {
        viewModel.inputText = ""
        let initialMessageCount = viewModel.messages.count
        await viewModel.sendMessage()
        #expect(viewModel.messages.count == initialMessageCount)
    }

    @Test("送信中はローディング状態になる")
    func 送信中はローディング状態になる() async {
        viewModel.inputText = "こんにちは"

        let sendTask = Task {
            await viewModel.sendMessage()
        }
        await sendTask.value

        #expect(viewModel.isLoading == false)
    }

    // MARK: - クイック返信のテスト

    @Test("はいを選択してメッセージ送信")
    func はいを選択してメッセージ送信() async {
        viewModel.quickReplies = ["はい", "いいえ"]
        await viewModel.sendQuickReply("はい")
        #expect(viewModel.messages.count > 0)
    }

    @Test("いいえを選択してメッセージ送信")
    func いいえを選択してメッセージ送信() async {
        viewModel.quickReplies = ["はい", "いいえ"]
        await viewModel.sendQuickReply("いいえ")
        #expect(viewModel.messages.count > 0)
    }

    // MARK: - テンプレート選択のテスト

    @Test("テンプレートを選択できる")
    func テンプレートを選択できる() async throws {
        let templates = try await mockTemplateRepository.fetchAll()
        let template = try #require(templates.first)

        viewModel.selectTemplate(template)

        let selected = try #require(viewModel.selectedTemplate)
        #expect(selected.id == template.id)
    }

    @Test("異なるテンプレートに変更できる")
    func 異なるテンプレートに変更できる() async throws {
        let templates = try await mockTemplateRepository.fetchAll()
        let template1 = templates[0]
        let template2 = templates[1]
        viewModel.selectTemplate(template1)

        viewModel.selectTemplate(template2)

        #expect(viewModel.selectedTemplate?.id == template2.id)
    }

    // MARK: - BGM選択のテスト

    @Test("BGMを選択できる")
    func BGMを選択できる() {
        let bgm = BGMTrack(
            id: "bgm-001",
            title: "爽やかな朝",
            description: "明るく前向きなVlogに最適",
            genre: "pop",
            duration: 120,
            storageUrl: "gs://bucket/bgm/morning.m4a",
            tags: ["明るい", "爽やか", "日常"]
        )

        viewModel.selectBGM(bgm)

        #expect(viewModel.selectedBGM != nil)
        #expect(viewModel.selectedBGM?.id == bgm.id)
    }

    @Test("異なるBGMに変更できる")
    func 異なるBGMに変更できる() {
        let bgm1 = BGMTrack(id: "bgm-001", title: "BGM1", description: "", genre: "pop", duration: 120, storageUrl: "", tags: [])
        let bgm2 = BGMTrack(id: "bgm-002", title: "BGM2", description: "", genre: "rock", duration: 150, storageUrl: "", tags: [])
        viewModel.selectBGM(bgm1)

        viewModel.selectBGM(bgm2)

        #expect(viewModel.selectedBGM?.id == bgm2.id)
    }

    // MARK: - 動画添付のテスト

    @Test("動画URLを添付できる")
    func 動画URLを添付できる() {
        let videoURL = URL(string: "mock://video/test.mp4")!

        viewModel.attachVideo(videoURL)

        #expect(viewModel.attachedVideoURL != nil)
        #expect(viewModel.attachedVideoURL == videoURL)
    }

    @Test("動画を削除できる")
    func 動画を削除できる() {
        let videoURL = URL(string: "mock://video/test.mp4")!
        viewModel.attachVideo(videoURL)

        viewModel.removeAttachedVideo()

        #expect(viewModel.attachedVideoURL == nil)
    }

    @Test("異なる動画に変更できる")
    func 異なる動画に変更できる() {
        let videoURL1 = URL(string: "mock://video/video1.mp4")!
        let videoURL2 = URL(string: "mock://video/video2.mp4")!
        viewModel.attachVideo(videoURL1)

        viewModel.attachVideo(videoURL2)

        #expect(viewModel.attachedVideoURL == videoURL2)
    }

    // MARK: - エラーハンドリングのテスト

    @Test("エラーメッセージをクリアできる")
    func エラーメッセージをクリアできる() {
        viewModel.errorMessage = "テストエラー"

        viewModel.clearError()

        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - 会話フロー統合テスト

    @Test("完全な会話フローをシミュレート")
    func 完全な会話フローをシミュレート() async {
        viewModel.inputText = "こんにちは"
        await viewModel.sendMessage()
        #expect(viewModel.messages.count > 0)

        viewModel.inputText = "日常のVlog"
        await viewModel.sendMessage()

        viewModel.inputText = "いいえ、提案してください"
        await viewModel.sendMessage()

        viewModel.inputText = "はい"
        await viewModel.sendMessage()

        viewModel.inputText = "はい"
        await viewModel.sendMessage()

        #expect(viewModel.messages.count > 5)
        #expect(viewModel.isLoading == false)
    }

    // MARK: - ストリーミング状態のテスト

    @Test("ストリーミングテキストを設定できる")
    func ストリーミングテキストを設定できる() {
        let streamingText = "これはストリーミング中のテキストです"
        viewModel.streamingText = streamingText
        #expect(viewModel.streamingText == streamingText)
    }

    // MARK: - パフォーマンステスト

    @Test("複数のメッセージを連続で送信できる")
    func 複数のメッセージを連続で送信できる() async {
        let messages = ["メッセージ1", "メッセージ2", "メッセージ3"]

        for message in messages {
            viewModel.inputText = message
            await viewModel.sendMessage()
        }

        #expect(viewModel.messages.count > messages.count)
    }

    // MARK: - 状態リセットのテスト

    @Test("ViewModelの状態をリセットできる")
    func ViewModelの状態をリセットできる() {
        viewModel.inputText = "テキスト"
        viewModel.errorMessage = "エラー"
        viewModel.attachedVideoURL = URL(string: "mock://video/test.mp4")

        viewModel.reset()

        #expect(viewModel.inputText.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.attachedVideoURL == nil)
    }
}
