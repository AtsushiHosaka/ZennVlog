import SwiftUI

/// チャットバブルコンポーネント
/// ユーザーとAIのメッセージを表示
struct ChatBubble: View {
    let message: String
    let isUser: Bool
    let timestamp: Date?
    let isStreaming: Bool

    init(message: String, isUser: Bool, timestamp: Date? = nil, isStreaming: Bool = false) {
        self.message = message
        self.isUser = isUser
        self.timestamp = timestamp
        self.isStreaming = isStreaming
    }

    init(message: ChatMessage, isStreaming: Bool = false) {
        self.message = message.content
        self.isUser = message.role == .user
        self.timestamp = message.timestamp
        self.isStreaming = isStreaming
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 60)
            } else {
                // AIアイコン
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.accentColor.opacity(0.2)))
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 0) {
                    Text(message)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isUser ? Color.accentColor : Color.gray.opacity(0.15))
                        .foregroundColor(isUser ? .black : .primary)
                        .cornerRadius(16)

                    if isStreaming {
                        Text("|")
                            .foregroundColor(.secondary)
                            .padding(.leading, 2)
                    }
                }

                if let timestamp = timestamp, !isStreaming {
                    Text(formatTime(timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if !isUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview("ユーザー") {
    ChatBubble(
        message: "旅行のVlogを作りたいです",
        isUser: true,
        timestamp: Date()
    )
}

#Preview("AI") {
    ChatBubble(
        message: "旅行のVlogですね！どんな旅行ですか？国内か海外か、期間や目的などを教えてください。",
        isUser: false,
        timestamp: Date()
    )
}

#Preview("ストリーミング中") {
    ChatBubble(
        message: "テンプレートを探しています",
        isUser: false,
        isStreaming: true
    )
}

#Preview("長いメッセージ") {
    ChatBubble(
        message: "これは長いメッセージのサンプルです。複数行にわたる場合もあります。Vlogのテンプレートを選ぶ際には、撮影する内容や雰囲気に合わせて選ぶことが重要です。",
        isUser: false,
        timestamp: Date()
    )
}

#Preview("会話") {
    VStack(spacing: 12) {
        ChatBubble(message: "こんにちは！", isUser: true)
        ChatBubble(message: "こんにちは！何を作りたいですか？", isUser: false)
        ChatBubble(message: "カフェ巡りのVlogを作りたいです", isUser: true)
    }
}

#Preview("ChatMessage使用") {
    let message = ChatMessage(role: .assistant, content: "Vlogを作成しましょう！")
    return ChatBubble(message: message)
}
