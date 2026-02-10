import SwiftUI

/// 思考プロセス可視化ビュー
/// タイムライン形式で思考ステップを表示
struct ThinkingProcessView: View {
    let steps: [ThinkingStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    // タイムラインインジケータ
                    VStack(spacing: 0) {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 24, height: 24)
                            .overlay {
                                Image(systemName: step.type.iconName)
                                    .font(.caption2)
                                    .foregroundColor(.white)
                            }

                        if index < steps.count - 1 {
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.4))
                                .frame(width: 2)
                                .frame(minHeight: 20)
                        }
                    }

                    // ステップ内容
                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.type.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text(step.description)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .padding(.bottom, index < steps.count - 1 ? 12 : 0)

                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview("複数ステップ") {
    ThinkingProcessView(
        steps: [
            ThinkingStep(type: .reasoning, description: "ユーザーは旅行Vlogを作りたいようです"),
            ThinkingStep(type: .analyzing, description: "旅行の種類と期間を確認する必要があります"),
            ThinkingStep(type: .planning, description: "テンプレート検索の準備をします"),
            ThinkingStep(type: .concluding, description: "質問を投げかけます")
        ]
    )
    .padding()
}

#Preview("単一ステップ") {
    ThinkingProcessView(
        steps: [
            ThinkingStep(type: .reasoning, description: "テーマについて考えています")
        ]
    )
    .padding()
}

#Preview("分析中") {
    ThinkingProcessView(
        steps: [
            ThinkingStep(type: .analyzing, description: "添付された動画を解析しています"),
            ThinkingStep(type: .planning, description: "セグメントへのマッピングを計画中")
        ]
    )
    .padding()
}
