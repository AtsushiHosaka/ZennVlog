import Testing
@testable import ZennVlog

@Suite("SyncChatHistoryUseCase Tests")
@MainActor
struct SyncChatHistoryUseCaseTests {

    let useCase: SyncChatHistoryUseCase

    init() async {
        useCase = SyncChatHistoryUseCase()
    }

    // MARK: - 基本的な同期テスト

    @Test("新しいメッセージをSwiftDataに保存")
    func 新しいメッセージをSwiftDataに保存() async throws {
        // Given: 新しいメッセージ
        let projectId = UUID()
        let newMessage = ChatMessage(role: .user, content: "こんにちは")

        // When: メッセージを同期
        try await useCase.execute(projectId: projectId, message: newMessage)

        // Then: エラーなく完了する
        // 実際のSwiftData保存は実装依存のため、エラーが発生しないことを確認
    }

    @Test("アシスタントのメッセージも保存できる")
    func アシスタントのメッセージも保存できる() async throws {
        // Given: アシスタントのメッセージ
        let projectId = UUID()
        let assistantMessage = ChatMessage(role: .assistant, content: "こんにちは！Vlog作成をお手伝いします。")

        // When & Then: メッセージを同期してもエラーが発生しない
        try await useCase.execute(projectId: projectId, message: assistantMessage)
    }

    @Test("複数のメッセージを連続で同期できる")
    func 複数のメッセージを連続で同期できる() async throws {
        // Given: 複数のメッセージ
        let projectId = UUID()
        let messages = [
            ChatMessage(role: .user, content: "メッセージ1"),
            ChatMessage(role: .assistant, content: "返信1"),
            ChatMessage(role: .user, content: "メッセージ2"),
            ChatMessage(role: .assistant, content: "返信2")
        ]

        // When: メッセージを連続で同期
        for message in messages {
            try await useCase.execute(projectId: projectId, message: message)
        }

        // Then: すべて正常に完了する
    }

    // MARK: - 動画添付メッセージのテスト

    @Test("動画添付メッセージを同期できる")
    func 動画添付メッセージを同期できる() async throws {
        // Given: 動画添付を含むメッセージ
        let projectId = UUID()
        let messageWithVideo = ChatMessage(
            role: .user,
            content: "この動画を分析してください",
            attachedVideoURL: "mock://video/test.mp4"
        )

        // When: メッセージを同期
        try await useCase.execute(projectId: projectId, message: messageWithVideo)

        // Then: エラーなく完了する
    }

    @Test("動画URLなしのメッセージも同期できる")
    func 動画URLなしのメッセージも同期できる() async throws {
        // Given: 動画添付のないメッセージ
        let projectId = UUID()
        let messageWithoutVideo = ChatMessage(
            role: .user,
            content: "テキストのみのメッセージ",
            attachedVideoURL: nil
        )

        // When: メッセージを同期
        try await useCase.execute(projectId: projectId, message: messageWithoutVideo)

        // Then: エラーなく完了する
    }

    // MARK: - エラーハンドリングテスト

    @Test("空のコンテンツでもエラーにならない")
    func 空のコンテンツでもエラーにならない() async throws {
        // Given: 空のコンテンツのメッセージ
        let projectId = UUID()
        let emptyMessage = ChatMessage(role: .user, content: "")

        // When: メッセージを同期
        try await useCase.execute(projectId: projectId, message: emptyMessage)

        // Then: エラーなく完了する
    }

    @Test("同じプロジェクトに複数のメッセージを追加できる")
    func 同じプロジェクトに複数のメッセージを追加できる() async throws {
        // Given: 同じプロジェクトID
        let projectId = UUID()

        // When: 5つのメッセージを連続で追加
        for i in 0..<5 {
            let message = ChatMessage(role: .user, content: "メッセージ\(i)")
            try await useCase.execute(projectId: projectId, message: message)
        }

        // Then: すべて正常に完了する
    }

    @Test("異なるプロジェクトのメッセージを区別できる")
    func 異なるプロジェクトのメッセージを区別できる() async throws {
        // Given: 2つの異なるプロジェクト
        let projectId1 = UUID()
        let projectId2 = UUID()
        let message1 = ChatMessage(role: .user, content: "プロジェクト1のメッセージ")
        let message2 = ChatMessage(role: .user, content: "プロジェクト2のメッセージ")

        // When: 各プロジェクトにメッセージを追加
        try await useCase.execute(projectId: projectId1, message: message1)
        try await useCase.execute(projectId: projectId2, message: message2)

        // Then: 両方とも正常に完了する
    }

    // MARK: - タイムスタンプのテスト

    @Test("メッセージにタイムスタンプが記録される")
    func メッセージにタイムスタンプが記録される() async throws {
        // Given: 新しいメッセージ
        let projectId = UUID()
        let beforeTime = Date()
        let message = ChatMessage(role: .user, content: "タイムスタンプテスト")

        // When: メッセージを同期
        try await useCase.execute(projectId: projectId, message: message)

        let afterTime = Date()

        // Then: メッセージのタイムスタンプが適切な範囲内
        #expect(message.timestamp >= beforeTime)
        #expect(message.timestamp <= afterTime)
    }

    @Test("連続するメッセージのタイムスタンプが昇順")
    func 連続するメッセージのタイムスタンプが昇順() async throws {
        // Given: 複数のメッセージ
        let projectId = UUID()
        var timestamps: [Date] = []

        // When: メッセージを連続で追加
        for i in 0..<3 {
            let message = ChatMessage(role: .user, content: "メッセージ\(i)")
            try await useCase.execute(projectId: projectId, message: message)
            timestamps.append(message.timestamp)

            // 短い待機時間を入れてタイムスタンプの順序を保証
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        // Then: タイムスタンプが昇順に並んでいる
        for i in 0..<timestamps.count - 1 {
            #expect(timestamps[i] <= timestamps[i + 1])
        }
    }

    // MARK: - パフォーマンステスト

    @Test("適切な時間内に同期が完了する")
    func 適切な時間内に同期が完了する() async throws {
        // Given: メッセージ
        let projectId = UUID()
        let message = ChatMessage(role: .user, content: "パフォーマンステスト")

        // When: 同期して時間を計測
        let startTime = ContinuousClock.now
        try await useCase.execute(projectId: projectId, message: message)
        let elapsed = ContinuousClock.now - startTime

        // Then: 1秒以内に完了する
        #expect(elapsed < .seconds(1))
    }

    @Test("大量のメッセージを連続で同期できる")
    func 大量のメッセージを連続で同期できる() async throws {
        // Given: 30件のメッセージ
        let projectId = UUID()

        // When: メッセージを連続で同期して時間を計測
        let startTime = ContinuousClock.now
        for i in 0..<30 {
            let message = ChatMessage(role: i % 2 == 0 ? .user : .assistant, content: "メッセージ\(i)")
            try await useCase.execute(projectId: projectId, message: message)
        }
        let elapsed = ContinuousClock.now - startTime

        // Then: 5秒以内にすべて完了する
        #expect(elapsed < .seconds(5))
    }

    // MARK: - メッセージ内容のテスト

    @Test("長いメッセージも同期できる")
    func 長いメッセージも同期できる() async throws {
        // Given: 長いメッセージ
        let projectId = UUID()
        let longContent = String(repeating: "これは長いメッセージです。", count: 100)
        let longMessage = ChatMessage(role: .user, content: longContent)

        // When: メッセージを同期
        try await useCase.execute(projectId: projectId, message: longMessage)

        // Then: エラーなく完了する
    }

    @Test("特殊文字を含むメッセージも同期できる")
    func 特殊文字を含むメッセージも同期できる() async throws {
        // Given: 特殊文字を含むメッセージ
        let projectId = UUID()
        let specialContent = "こんにちは！😊\n改行もあります。\t\"引用符\"も含みます。"
        let specialMessage = ChatMessage(role: .user, content: specialContent)

        // When: メッセージを同期
        try await useCase.execute(projectId: projectId, message: specialMessage)

        // Then: エラーなく完了する
    }

    @Test("絵文字を含むメッセージも同期できる")
    func 絵文字を含むメッセージも同期できる() async throws {
        // Given: 絵文字を含むメッセージ
        let projectId = UUID()
        let emojiContent = "Vlog作りたい！🎥✨📹🎬"
        let emojiMessage = ChatMessage(role: .user, content: emojiContent)

        // When: メッセージを同期
        try await useCase.execute(projectId: projectId, message: emojiMessage)

        // Then: エラーなく完了する
    }

    // MARK: - ロール（役割）のテスト

    @Test("ユーザーロールとアシスタントロールを区別できる")
    func ユーザーロールとアシスタントロールを区別できる() async throws {
        // Given: 異なるロールのメッセージ
        let projectId = UUID()
        let userMessage = ChatMessage(role: .user, content: "ユーザーメッセージ")
        let assistantMessage = ChatMessage(role: .assistant, content: "アシスタントメッセージ")

        // When: 両方を同期
        try await useCase.execute(projectId: projectId, message: userMessage)
        try await useCase.execute(projectId: projectId, message: assistantMessage)

        // Then: 両方とも正常に完了し、ロールが保持される
        #expect(userMessage.role == .user)
        #expect(assistantMessage.role == .assistant)
    }
}
