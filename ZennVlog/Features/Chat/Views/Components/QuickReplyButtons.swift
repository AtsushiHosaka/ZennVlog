import SwiftUI

/// クイック返信ボタン群
/// はい/いいえなどの定型文を送信
struct QuickReplyButtons: View {
    let replies: [String]
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(replies, id: \.self) { reply in
                    Button {
                        onSelect(reply)
                    } label: {
                        Text(reply)
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.2))
                            .foregroundColor(.black)
                            .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

#Preview("はい/いいえ") {
    QuickReplyButtons(
        replies: ["はい", "いいえ"],
        onSelect: { _ in }
    )
}

#Preview("複数選択肢") {
    QuickReplyButtons(
        replies: ["日常", "旅行", "グルメ", "趣味", "その他"],
        onSelect: { _ in }
    )
}

#Preview("長い選択肢") {
    QuickReplyButtons(
        replies: ["テンプレートを見る", "自分で考える", "もう少し詳しく"],
        onSelect: { _ in }
    )
}
