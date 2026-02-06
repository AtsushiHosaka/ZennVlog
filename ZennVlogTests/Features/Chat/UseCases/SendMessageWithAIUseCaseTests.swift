import Foundation
import Testing
@testable import ZennVlog

@Suite("SendMessageWithAIUseCase Tests")
@MainActor
struct SendMessageWithAIUseCaseTests {

    let useCase: SendMessageWithAIUseCase
    let mockRepository: MockGeminiRepository

    init() async {
        mockRepository = MockGeminiRepository()
        useCase = SendMessageWithAIUseCase(repository: mockRepository)
    }

    // MARK: - 基本的なメッセージ送信テスト

    @Test("初回メッセージで挨拶を返す")
    func 初回メッセージで挨拶を返す() async throws {
        // Given: 空の履歴
        let message = "こんにちは"
        let history: [ChatMessageDTO] = []

        // When: メッセージを送信
        let response = try await useCase.execute(message: message, history: history)

        // Then: 挨拶と質問が返される
        #expect(response.text.contains("Vlog"))
        #expect(response.suggestedTemplate == nil)
        #expect(response.suggestedBGM == nil)
    }

    @Test("テーマを伝えると構成確認を返す")
    func テーマを伝えると構成確認を返す() async throws {
        // Given: 初回挨拶後の履歴
        let history: [ChatMessageDTO] = [
            ChatMessageDTO(role: .user, content: "こんにちは", attachedVideoURL: nil),
            ChatMessageDTO(role: .assistant, content: "こんにちは！Vlog作成をお手伝いします。", attachedVideoURL: nil)
        ]
        let message = "日常のVlogを作りたい"

        // When: テーマを送信
        let response = try await useCase.execute(message: message, history: history)

        // Then: 構成確認の質問が返される
        #expect(response.text.contains("構成"))
        #expect(response.suggestedTemplate == nil)
    }

    @Test("構成未定と答えるとテンプレート提案を返す")
    func 構成未定と答えるとテンプレート提案を返す() async throws {
        // Given: テーマ確認後の履歴
        let history: [ChatMessageDTO] = [
            ChatMessageDTO(role: .user, content: "こんにちは", attachedVideoURL: nil),
            ChatMessageDTO(role: .assistant, content: "こんにちは！", attachedVideoURL: nil),
            ChatMessageDTO(role: .user, content: "日常のVlog", attachedVideoURL: nil),
            ChatMessageDTO(role: .assistant, content: "構成は決まっていますか？", attachedVideoURL: nil)
        ]
        let message = "いいえ、提案してください"

        // When: 提案を依頼
        let response = try await useCase.execute(message: message, history: history)

        // Then: テンプレートが提案される
        let template = try #require(response.suggestedTemplate)
        #expect(template.id == "daily-vlog")
        #expect(template.name == "1日のVlog")
        #expect(!template.segments.isEmpty)
    }

    @Test("テンプレート承認でBGM提案を返す")
    func テンプレート承認でBGM提案を返す() async throws {
        // Given: テンプレート提案後の履歴
        let history: [ChatMessageDTO] = [
            ChatMessageDTO(role: .user, content: "こんにちは", attachedVideoURL: nil),
            ChatMessageDTO(role: .assistant, content: "こんにちは！", attachedVideoURL: nil),
            ChatMessageDTO(role: .user, content: "日常のVlog", attachedVideoURL: nil),
            ChatMessageDTO(role: .assistant, content: "構成は決まっていますか？", attachedVideoURL: nil),
            ChatMessageDTO(role: .user, content: "いいえ", attachedVideoURL: nil),
            ChatMessageDTO(role: .assistant, content: "テンプレートを提案します", attachedVideoURL: nil)
        ]
        let message = "はい、お願いします"

        // When: テンプレートを承認
        let response = try await useCase.execute(message: message, history: history)

        // Then: BGMが提案される
        let bgm = try #require(response.suggestedBGM)
        #expect(bgm.id == "bgm-001")
        #expect(bgm.title == "爽やかな朝")
    }

    @Test("BGM承認で撮影開始メッセージを返す")
    func BGM承認で撮影開始メッセージを返す() async throws {
        // Given: BGM提案後の履歴
        let history: [ChatMessageDTO] = [
            ChatMessageDTO(role: .user, content: "こんにちは", attachedVideoURL: nil),
            ChatMessageDTO(role: .assistant, content: "こんにちは！", attachedVideoURL: nil),
            ChatMessageDTO(role: .user, content: "日常のVlog", attachedVideoURL: nil),
            ChatMessageDTO(role: .assistant, content: "構成は決まっていますか？", attachedVideoURL: nil),
            ChatMessageDTO(role: .user, content: "いいえ", attachedVideoURL: nil),
            ChatMessageDTO(role: .assistant, content: "テンプレートを提案します", attachedVideoURL: nil),
            ChatMessageDTO(role: .user, content: "はい", attachedVideoURL: nil),
            ChatMessageDTO(role: .assistant, content: "BGMを提案します", attachedVideoURL: nil)
        ]
        let message = "はい、それでお願いします"

        // When: BGMを承認
        let response = try await useCase.execute(message: message, history: history)

        // Then: 撮影開始メッセージが返される
        #expect(response.text.contains("撮影"))
        #expect(response.suggestedTemplate == nil)
        #expect(response.suggestedBGM == nil)
    }

    // MARK: - エラーハンドリングテスト

    @Test("空のメッセージでもエラーにならない")
    func 空のメッセージでもエラーにならない() async throws {
        // Given: 空のメッセージ
        let message = ""
        let history: [ChatMessageDTO] = []

        // When: 空のメッセージを送信
        let response = try await useCase.execute(message: message, history: history)

        // Then: レスポンスが返される（エラーにならない）
        #expect(!response.text.isEmpty)
    }

    @Test("長い履歴でもエラーにならない")
    func 長い履歴でもエラーにならない() async throws {
        // Given: 20件の履歴
        var history: [ChatMessageDTO] = []
        for i in 0..<20 {
            history.append(ChatMessageDTO(role: .user, content: "メッセージ\(i)", attachedVideoURL: nil))
            history.append(ChatMessageDTO(role: .assistant, content: "返信\(i)", attachedVideoURL: nil))
        }
        let message = "新しいメッセージ"

        // When: メッセージを送信
        let response = try await useCase.execute(message: message, history: history)

        // Then: レスポンスが返される
        #expect(!response.text.isEmpty)
    }

    // MARK: - 会話フローテスト

    @Test("完全な会話フローが正しく動作する")
    func 完全な会話フローが正しく動作する() async throws {
        // Given: 初期状態
        var history: [ChatMessageDTO] = []
        var responseCount = 0

        // When & Then: ステップ1 - 初回挨拶
        let response1 = try await useCase.execute(message: "こんにちは", history: history)
        #expect(!response1.text.isEmpty)
        history.append(ChatMessageDTO(role: .user, content: "こんにちは", attachedVideoURL: nil))
        history.append(ChatMessageDTO(role: .assistant, content: response1.text, attachedVideoURL: nil))
        responseCount += 1

        // When & Then: ステップ2 - テーマ伝達
        let response2 = try await useCase.execute(message: "日常のVlog", history: history)
        #expect(!response2.text.isEmpty)
        history.append(ChatMessageDTO(role: .user, content: "日常のVlog", attachedVideoURL: nil))
        history.append(ChatMessageDTO(role: .assistant, content: response2.text, attachedVideoURL: nil))
        responseCount += 1

        // When & Then: ステップ3 - テンプレート提案依頼
        let response3 = try await useCase.execute(message: "いいえ、提案してください", history: history)
        #expect(!response3.text.isEmpty)
        history.append(ChatMessageDTO(role: .user, content: "いいえ、提案してください", attachedVideoURL: nil))
        history.append(ChatMessageDTO(role: .assistant, content: response3.text, attachedVideoURL: nil))
        responseCount += 1

        // When & Then: ステップ4 - テンプレート承認
        let response4 = try await useCase.execute(message: "はい", history: history)
        #expect(!response4.text.isEmpty)
        history.append(ChatMessageDTO(role: .user, content: "はい", attachedVideoURL: nil))
        history.append(ChatMessageDTO(role: .assistant, content: response4.text, attachedVideoURL: nil))
        responseCount += 1

        // When & Then: ステップ5 - BGM承認
        let response5 = try await useCase.execute(message: "はい", history: history)
        #expect(!response5.text.isEmpty)
        responseCount += 1

        // Then: 5回のレスポンスがすべて取得できた
        #expect(responseCount == 5)
        #expect(history.count == 8) // 4ステップ x 2メッセージ（user + assistant）
    }

    // MARK: - パフォーマンステスト

    @Test("レスポンスが適切な時間内に返される")
    func レスポンスが適切な時間内に返される() async throws {
        // Given: シンプルなメッセージ
        let message = "こんにちは"
        let history: [ChatMessageDTO] = []

        // When: メッセージを送信してレスポンス時間を計測
        let startTime = ContinuousClock.now
        _ = try await useCase.execute(message: message, history: history)
        let elapsed = ContinuousClock.now - startTime

        // Then: 3秒以内にレスポンスが返される（ネットワーク遅延800ms + マージン）
        #expect(elapsed < .seconds(3))
    }
}
