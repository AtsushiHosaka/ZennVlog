import SwiftUI

/// ツール実行中インジケータ
/// ツールの実行状態を表示
struct ToolExecutionIndicator: View {
    let status: ToolExecutionStatus

    var body: some View {
        HStack(spacing: 12) {
            if status.state == .executing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
            } else if status.state == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(status.displayMessage)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                if let result = status.result, status.state == .completed {
                    Text(result)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.accentColor.opacity(0.15))
        .cornerRadius(12)
    }
}

#Preview("テンプレート検索中") {
    ToolExecutionIndicator(
        status: ToolExecutionStatus(
            toolName: "templateSearch",
            state: .executing
        )
    )
    .padding()
}

#Preview("検索完了") {
    ToolExecutionIndicator(
        status: ToolExecutionStatus(
            toolName: "templateSearch",
            state: .completed,
            result: "3件のテンプレートが見つかりました"
        )
    )
    .padding()
}

#Preview("動画分析中") {
    ToolExecutionIndicator(
        status: ToolExecutionStatus(
            toolName: "videoAnalysis",
            state: .executing
        )
    )
    .padding()
}

#Preview("失敗") {
    ToolExecutionIndicator(
        status: ToolExecutionStatus(
            toolName: "templateSearch",
            state: .failed,
            result: "ネットワークエラー"
        )
    )
    .padding()
}
