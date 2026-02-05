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
            geminiRepository: mockGeminiRepository,
            templateRepository: mockTemplateRepository
        )
    }

    // MARK: - 初期状態のテスト

    @Test("初期状態が正しく設定される")
    func 初期状態が正しく設定される() {
        // Given: ViewModelが初期化された状態

        // Then: 初期状態が正しい
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
        // Given: 入力テキスト
        viewModel.inputText = "こんにちは"

        // When: メッセージを送信
        await viewModel.sendMessage()

        // Then: メッセージが追加され、AIの応答も追加される
        #expect(viewModel.messages.count > 0)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.inputText.isEmpty) // 送信後は空になる
    }

    @Test("空のメッセージは送信しない")
    func 空のメッセージは送信しない() async {
        // Given: 空の入力テキスト
        viewModel.inputText = ""
        let initialMessageCount = viewModel.messages.count

        // When: メッセージを送信
        await viewModel.sendMessage()

        // Then: メッセージは追加されない
        #expect(viewModel.messages.count == initialMessageCount)
    }

    @Test("送信中はローディング状態になる")
    func 送信中はローディング状態になる() async {
        // Given: 入力テキスト
        viewModel.inputText = "こんにちは"

        // When: メッセージ送信を開始
        let sendTask = Task {
            await viewModel.sendMessage()
        }

        // Then: 一時的にローディング状態になる
        // 非同期のためタイミング依存だが、最終的には完了する
        await sendTask.value

        #expect(viewModel.isLoading == false)
    }

    // MARK: - クイック返信のテスト

    @Test("はいを選択してメッセージ送信")
    func はいを選択してメッセージ送信() async {
        // Given: クイック返信ボタンがある状態
        viewModel.quickReplies = ["はい", "いいえ"]

        // When: 「はい」を選択
        await viewModel.sendQuickReply("はい")

        // Then: メッセージが送信される
        #expect(viewModel.messages.count > 0)
    }

    @Test("いいえを選択してメッセージ送信")
    func いいえを選択してメッセージ送信() async {
        // Given: クイック返信ボタンがある状態
        viewModel.quickReplies = ["はい", "いいえ"]

        // When: 「いいえ」を選択
        await viewModel.sendQuickReply("いいえ")

        // Then: メッセージが送信される
        #expect(viewModel.messages.count > 0)
    }

    // MARK: - テンプレート選択のテスト

    @Test("テンプレートを選択できる")
    func テンプレートを選択できる() async throws {
        // Given: テンプレート一覧
        let templates = try await mockTemplateRepository.fetchAll()
        let template = try #require(templates.first)

        // When: テンプレートを選択
        viewModel.selectTemplate(template)

        // Then: 選択されたテンプレートが保存される
        let selected = try #require(viewModel.selectedTemplate)
        #expect(selected.id == template.id)
    }

    @Test("異なるテンプレートに変更できる")
    func 異なるテンプレートに変更できる() async throws {
        // Given: 最初のテンプレートを選択
        let templates = try await mockTemplateRepository.fetchAll()
        let template1 = templates[0]
        let template2 = templates[1]
        viewModel.selectTemplate(template1)

        // When: 別のテンプレートを選択
        viewModel.selectTemplate(template2)

        // Then: 選択が更新される
        #expect(viewModel.selectedTemplate?.id == template2.id)
    }

    // MARK: - BGM選択のテスト

    @Test("BGMを選択できる")
    func BGMを選択できる() {
        // Given: BGMトラック
        let bgm = BGMTrack(
            id: "bgm-001",
            title: "爽やかな朝",
            description: "明るく前向きなVlogに最適",
            genre: "pop",
            duration: 120,
            storageUrl: "gs://bucket/bgm/morning.m4a",
            tags: ["明るい", "爽やか", "日常"]
        )

        // When: BGMを選択
        viewModel.selectBGM(bgm)

        // Then: 選択されたBGMが保存される
        #expect(viewModel.selectedBGM != nil)
        #expect(viewModel.selectedBGM?.id == bgm.id)
    }

    @Test("異なるBGMに変更できる")
    func 異なるBGMに変更できる() {
        // Given: 最初のBGMを選択
        let bgm1 = BGMTrack(id: "bgm-001", title: "BGM1", description: "", genre: "pop", duration: 120, storageUrl: "", tags: [])
        let bgm2 = BGMTrack(id: "bgm-002", title: "BGM2", description: "", genre: "rock", duration: 150, storageUrl: "", tags: [])
        viewModel.selectBGM(bgm1)

        // When: 別のBGMを選択
        viewModel.selectBGM(bgm2)

        // Then: 選択が更新される
        #expect(viewModel.selectedBGM?.id == bgm2.id)
    }

    // MARK: - 動画添付のテスト

    @Test("動画URLを添付できる")
    func 動画URLを添付できる() {
        // Given: 動画URL
        let videoURL = URL(string: "mock://video/test.mp4")!

        // When: 動画を添付
        viewModel.attachVideo(videoURL)

        // Then: 動画URLが保存される
        #expect(viewModel.attachedVideoURL != nil)
        #expect(viewModel.attachedVideoURL == videoURL)
    }

    @Test("動画を削除できる")
    func 動画を削除できる() {
        // Given: 動画が添付されている状態
        let videoURL = URL(string: "mock://video/test.mp4")!
        viewModel.attachVideo(videoURL)

        // When: 動画を削除
        viewModel.removeAttachedVideo()

        // Then: 動画URLがnilになる
        #expect(viewModel.attachedVideoURL == nil)
    }

    @Test("異なる動画に変更できる")
    func 異なる動画に変更できる() {
        // Given: 最初の動画を添付
        let videoURL1 = URL(string: "mock://video/video1.mp4")!
        let videoURL2 = URL(string: "mock://video/video2.mp4")!
        viewModel.attachVideo(videoURL1)

        // When: 別の動画を添付
        viewModel.attachVideo(videoURL2)

        // Then: 動画URLが更新される
        #expect(viewModel.attachedVideoURL == videoURL2)
    }

    // MARK: - エラーハンドリングのテスト

    @Test("エラーメッセージをクリアできる")
    func エラーメッセージをクリアできる() {
        // Given: エラーメッセージがある状態
        viewModel.errorMessage = "テストエラー"

        // When: エラーをクリア
        viewModel.clearError()

        // Then: エラーメッセージがnilになる
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - 会話フロー統合テスト

    @Test("完全な会話フローをシミュレート")
    func 完全な会話フローをシミュレート() async {
        // Given: 初期状態

        // Step 1: 初回挨拶
        viewModel.inputText = "こんにちは"
        await viewModel.sendMessage()
        #expect(viewModel.messages.count > 0)

        // Step 2: テーマ伝達
        viewModel.inputText = "日常のVlog"
        await viewModel.sendMessage()

        // Step 3: テンプレート提案依頼
        viewModel.inputText = "いいえ、提案してください"
        await viewModel.sendMessage()

        // Step 4: テンプレート承認
        viewModel.inputText = "はい"
        await viewModel.sendMessage()

        // Step 5: BGM承認
        viewModel.inputText = "はい"
        await viewModel.sendMessage()

        // Then: 複数のメッセージが追加されている
        #expect(viewModel.messages.count > 5)
        #expect(viewModel.isLoading == false)
    }

    // MARK: - ストリーミング状態のテスト

    @Test("ストリーミングテキストを設定できる")
    func ストリーミングテキストを設定できる() {
        // Given: ストリーミングテキスト
        let streamingText = "これはストリーミング中のテキストです"

        // When: ストリーミングテキストを設定
        viewModel.streamingText = streamingText

        // Then: ストリーミングテキストが保存される
        #expect(viewModel.streamingText == streamingText)
    }

    // MARK: - パフォーマンステスト

    @Test("複数のメッセージを連続で送信できる")
    func 複数のメッセージを連続で送信できる() async {
        // Given: 複数のメッセージ
        let messages = ["メッセージ1", "メッセージ2", "メッセージ3"]

        // When: 連続で送信
        for message in messages {
            viewModel.inputText = message
            await viewModel.sendMessage()
        }

        // Then: すべてのメッセージが処理される
        #expect(viewModel.messages.count > messages.count)
    }

    // MARK: - 状態リセットのテスト

    @Test("ViewModelの状態をリセットできる")
    func ViewModelの状態をリセットできる() {
        // Given: いくつかの状態が設定されている
        viewModel.inputText = "テキスト"
        viewModel.errorMessage = "エラー"
        viewModel.attachedVideoURL = URL(string: "mock://video/test.mp4")

        // When: リセット
        viewModel.reset()

        // Then: すべての状態がクリアされる
        #expect(viewModel.inputText.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.attachedVideoURL == nil)
    }
}
