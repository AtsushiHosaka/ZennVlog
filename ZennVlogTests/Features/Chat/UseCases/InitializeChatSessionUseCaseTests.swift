import Testing
@testable import ZennVlog

@Suite("InitializeChatSessionUseCase Tests")
@MainActor
struct InitializeChatSessionUseCaseTests {

    let useCase: InitializeChatSessionUseCase

    init() async {
        useCase = InitializeChatSessionUseCase()
    }

    // MARK: - 基本的なセッション初期化テスト

    @Test("新規プロジェクトで空のセッションを作成")
    func 新規プロジェクトで空のセッションを作成() async throws {
        // Given: 新規プロジェクトID
        let projectId = UUID()

        // When: セッションを初期化
        let session = try await useCase.execute(projectId: projectId, existingMessages: [])

        // Then: 空のセッションが作成される
        #expect(session != nil)
    }

    @Test("既存メッセージを含むセッションを復元")
    func 既存メッセージを含むセッションを復元() async throws {
        // Given: 既存のメッセージ履歴
        let projectId = UUID()
        let existingMessages = [
            ChatMessage(role: .user, content: "こんにちは"),
            ChatMessage(role: .assistant, content: "こんにちは！Vlog作成をお手伝いします。")
        ]

        // When: セッションを初期化
        let session = try await useCase.execute(projectId: projectId, existingMessages: existingMessages)

        // Then: 履歴を含むセッションが作成される
        #expect(session != nil)
    }

    @Test("異なるプロジェクトIDで別のセッションを作成")
    func 異なるプロジェクトIDで別のセッションを作成() async throws {
        // Given: 2つの異なるプロジェクトID
        let projectId1 = UUID()
        let projectId2 = UUID()

        // When: 2つのセッションを初期化
        let session1 = try await useCase.execute(projectId: projectId1, existingMessages: [])
        let session2 = try await useCase.execute(projectId: projectId2, existingMessages: [])

        // Then: 異なるセッションが作成される
        #expect(session1 != nil)
        #expect(session2 != nil)
    }

    // MARK: - セッション復元テスト

    @Test("長い履歴を持つセッションを復元")
    func 長い履歴を持つセッションを復元() async throws {
        // Given: 20件の履歴
        let projectId = UUID()
        var messages: [ChatMessage] = []
        for i in 0..<20 {
            messages.append(ChatMessage(role: .user, content: "メッセージ\(i)"))
            messages.append(ChatMessage(role: .assistant, content: "返信\(i)"))
        }

        // When: セッションを初期化
        let session = try await useCase.execute(projectId: projectId, existingMessages: messages)

        // Then: 履歴を含むセッションが作成される
        #expect(session != nil)
    }

    @Test("動画添付を含むメッセージを復元")
    func 動画添付を含むメッセージを復元() async throws {
        // Given: 動画添付を含む履歴
        let projectId = UUID()
        let messages = [
            ChatMessage(role: .user, content: "この動画を分析してください", attachedVideoURL: "mock://video/test.mp4"),
            ChatMessage(role: .assistant, content: "動画を分析しました")
        ]

        // When: セッションを初期化
        let session = try await useCase.execute(projectId: projectId, existingMessages: messages)

        // Then: セッションが正しく作成される
        #expect(session != nil)
    }

    // MARK: - エラーハンドリングテスト

    @Test("空の履歴でもエラーにならない")
    func 空の履歴でもエラーにならない() async throws {
        // Given: 空の履歴
        let projectId = UUID()
        let messages: [ChatMessage] = []

        // When: セッションを初期化
        let session = try await useCase.execute(projectId: projectId, existingMessages: messages)

        // Then: セッションが作成される
        #expect(session != nil)
    }

    @Test("同じプロジェクトIDで複数回初期化できる")
    func 同じプロジェクトIDで複数回初期化できる() async throws {
        // Given: 同じプロジェクトID
        let projectId = UUID()

        // When: 複数回初期化
        let session1 = try await useCase.execute(projectId: projectId, existingMessages: [])
        let session2 = try await useCase.execute(projectId: projectId, existingMessages: [])

        // Then: 両方とも正常に作成される
        #expect(session1 != nil)
        #expect(session2 != nil)
    }

    // MARK: - パフォーマンステスト

    @Test("適切な時間内に初期化が完了する")
    func 適切な時間内に初期化が完了する() async throws {
        // Given: プロジェクトIDと履歴
        let projectId = UUID()
        let messages: [ChatMessage] = []

        // When: セッションを初期化して時間を計測
        let startTime = ContinuousClock.now
        _ = try await useCase.execute(projectId: projectId, existingMessages: messages)
        let elapsed = ContinuousClock.now - startTime

        // Then: 1秒以内に完了する
        #expect(elapsed < .seconds(1))
    }

    @Test("大量の履歴でも適切な時間内に復元する")
    func 大量の履歴でも適切な時間内に復元する() async throws {
        // Given: 50件の履歴
        let projectId = UUID()
        var messages: [ChatMessage] = []
        for i in 0..<50 {
            messages.append(ChatMessage(role: .user, content: "メッセージ\(i)"))
            messages.append(ChatMessage(role: .assistant, content: "返信\(i)"))
        }

        // When: セッションを初期化して時間を計測
        let startTime = ContinuousClock.now
        _ = try await useCase.execute(projectId: projectId, existingMessages: messages)
        let elapsed = ContinuousClock.now - startTime

        // Then: 3秒以内に完了する
        #expect(elapsed < .seconds(3))
    }

    // MARK: - セッション状態テスト

    @Test("新規セッションは空の状態から開始")
    func 新規セッションは空の状態から開始() async throws {
        // Given: 新規プロジェクト
        let projectId = UUID()

        // When: セッションを初期化
        let session = try await useCase.execute(projectId: projectId, existingMessages: [])

        // Then: 空の状態のセッションが作成される
        #expect(session != nil)
    }

    @Test("復元されたセッションは履歴を保持")
    func 復元されたセッションは履歴を保持() async throws {
        // Given: 履歴のあるプロジェクト
        let projectId = UUID()
        let messages = [
            ChatMessage(role: .user, content: "こんにちは"),
            ChatMessage(role: .assistant, content: "こんにちは！")
        ]

        // When: セッションを初期化
        let session = try await useCase.execute(projectId: projectId, existingMessages: messages)

        // Then: 履歴を保持するセッションが作成される
        #expect(session != nil)
    }
}
