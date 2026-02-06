import Foundation

actor MockGeminiRepository: GeminiRepositoryProtocol {

    // MARK: - GeminiRepositoryProtocol

    func sendMessage(_ message: String, history: [ChatMessageDTO]) async throws -> GeminiChatResponse {
        try await simulateNetworkDelay()
        return generateMockResponse(for: message, history: history)
    }

    func analyzeVideo(url: URL) async throws -> VideoAnalysisResult {
        try await simulateLongNetworkDelay()
        return VideoAnalysisResult(
            segments: [
                AnalyzedSegment(startSeconds: 0, endSeconds: 5, description: "人物が画面に映っている"),
                AnalyzedSegment(startSeconds: 5, endSeconds: 12, description: "屋外の風景"),
                AnalyzedSegment(startSeconds: 12, endSeconds: 20, description: "食事のシーン")
            ]
        )
    }

    // MARK: - Private Methods

    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: 800_000_000)
    }

    private func simulateLongNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: 2_000_000_000)
    }

    /// 会話履歴から現在の状態を推測
    /// 0=initial, 1=askingTheme, 2=askingStructure, 3=suggestingTemplate, 4=suggestingBGM, 5=complete
    private func detectStateFromHistory(_ history: [ChatMessageDTO]) -> Int {
        // 最後のassistantメッセージを見て状態を判定
        guard let lastAssistantMessage = history.last(where: { $0.role == .assistant }) else {
            return history.isEmpty ? 0 : 1
        }

        let content = lastAssistantMessage.content.lowercased()

        // BGM提案後（assistant が BGM を提案した）
        if content.contains("bgmは") || content.contains("bgmを提案") {
            return 4
        }

        // テンプレート提案後（assistant がテンプレートを提案した）
        if content.contains("こちらのテンプレート") || content.contains("テンプレートを提案") {
            return 3
        }

        // 構成確認後（assistant が構成を聞いた）
        if content.contains("構成は決まって") {
            return 2
        }

        // テーマを聞いた直後
        if content.contains("どんなテーマ") || content.contains("テーマの") {
            return 1
        }

        // 初回挨拶後（履歴がある）
        return 1
    }

    private func generateMockResponse(for message: String, history: [ChatMessageDTO]) -> GeminiChatResponse {
        let lowerMessage = message.lowercased()
        let stateIndex = detectStateFromHistory(history)

        // 初回挨拶
        if history.isEmpty {
            return GeminiChatResponse(
                text: "こんにちは！Vlog作成をお手伝いします。\n\nまず、どんなテーマのVlogを作りたいですか？\n例：日常、旅行、グルメ、趣味など",
                suggestedTemplate: nil,
                suggestedBGM: nil
            )
        }

        // テーマを受け取った後 → 構成確認
        if stateIndex == 1 {
            return GeminiChatResponse(
                text: "素敵ですね！\n\n構成は決まっていますか？決まっていなければ、いくつかテンプレートを提案できます。",
                suggestedTemplate: nil,
                suggestedBGM: nil
            )
        }

        // テンプレート提案を依頼された
        if stateIndex == 2 && (lowerMessage.contains("いいえ") || lowerMessage.contains("決まってない") || lowerMessage.contains("提案")) {
            let template = TemplateDTO(
                id: "daily-vlog",
                name: "1日のVlog",
                description: "朝から夜までの1日を記録するテンプレート",
                referenceVideoUrl: "https://youtube.com/example1",
                explanation: "朝→昼→夜の流れで、日常の何気ない瞬間を切り取ります",
                segments: [
                    SegmentDTO(order: 0, startSec: 0, endSec: 5, description: "オープニング"),
                    SegmentDTO(order: 1, startSec: 5, endSec: 15, description: "朝の様子"),
                    SegmentDTO(order: 2, startSec: 15, endSec: 30, description: "昼の活動"),
                    SegmentDTO(order: 3, startSec: 30, endSec: 45, description: "夜のシーン"),
                    SegmentDTO(order: 4, startSec: 45, endSec: 50, description: "エンディング")
                ]
            )
            return GeminiChatResponse(
                text: "こちらのテンプレートはいかがでしょうか？\n\n【1日のVlog】\n朝→昼→夜の流れで、日常の何気ない瞬間を切り取ります。\n\nこの構成でよろしいですか？",
                suggestedTemplate: template,
                suggestedBGM: nil
            )
        }

        // テンプレート承認 → BGM提案
        if stateIndex == 3 && (lowerMessage.contains("はい") || lowerMessage.contains("いい") || lowerMessage.contains("ok") || lowerMessage.contains("お願い")) {
            let bgm = BGMTrack(
                id: "bgm-001",
                title: "爽やかな朝",
                description: "明るく前向きなVlogに最適",
                genre: "pop",
                duration: 120,
                storageUrl: "gs://bucket/bgm/morning.m4a",
                tags: ["明るい", "爽やか", "日常"]
            )
            return GeminiChatResponse(
                text: "テンプレートが決まりました！\n\nBGMは「爽やかな朝」がおすすめです。明るく前向きな雰囲気にぴったりですよ。\n\nこのBGMでよろしいですか？",
                suggestedTemplate: nil,
                suggestedBGM: bgm
            )
        }

        // BGM承認 → 撮影開始
        if stateIndex == 4 && (lowerMessage.contains("はい") || lowerMessage.contains("いい") || lowerMessage.contains("ok") || lowerMessage.contains("お願い")) {
            return GeminiChatResponse(
                text: "準備が整いました！\n\n撮影を始めましょう。各セグメントの説明に沿って動画を撮影してください。",
                suggestedTemplate: nil,
                suggestedBGM: nil
            )
        }

        return GeminiChatResponse(
            text: "承知しました。他にご質問があればお聞きください。",
            suggestedTemplate: nil,
            suggestedBGM: nil
        )
    }
}
