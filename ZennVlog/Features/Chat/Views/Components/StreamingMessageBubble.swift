import SwiftUI

/// ストリーミング用メッセージバブル
/// カーソル点滅アニメーション付きでテキストを表示
struct StreamingMessageBubble: View {
    let text: String
    let isComplete: Bool

    @State private var showCursor = true

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // AIアイコン
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundColor(.purple)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.purple.opacity(0.1)))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    Text(text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.15))
                        .foregroundColor(.primary)
                        .cornerRadius(16)

                    if !isComplete {
                        Text("|")
                            .foregroundColor(.purple)
                            .opacity(showCursor ? 1 : 0)
                            .animation(.easeInOut(duration: 0.5).repeatForever(), value: showCursor)
                            .padding(.leading, 2)
                    }
                }
            }

            Spacer(minLength: 60)
        }
        .onAppear {
            showCursor = false
        }
    }
}

#Preview("ストリーミング中") {
    StreamingMessageBubble(
        text: "旅行のVlogですね！どんな旅行ですか？",
        isComplete: false
    )
    .padding()
}

#Preview("完了") {
    StreamingMessageBubble(
        text: "旅行のVlogですね！どんな旅行ですか？国内か海外か、期間や目的などを教えてください。",
        isComplete: true
    )
    .padding()
}

#Preview("短いテキスト") {
    StreamingMessageBubble(
        text: "なるほど",
        isComplete: false
    )
    .padding()
}
