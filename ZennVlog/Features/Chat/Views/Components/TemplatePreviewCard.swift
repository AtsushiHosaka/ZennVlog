import SwiftUI

/// テンプレートプレビューカード
/// 参考動画サムネイル、詳細情報、選択ボタンを表示
struct TemplatePreviewCard: View {
    let template: TemplateDTO
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // サムネイル（16:9）
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(16/9, contentMode: .fit)

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.8))
            }

            // テンプレート情報
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(template.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                if !template.explanation.isEmpty {
                    Text(template.explanation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .padding(.top, 4)
                }

                // セグメント数
                HStack {
                    Image(systemName: "film.stack")
                        .font(.caption)
                    Text("\(template.segments.count)セグメント")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding(.top, 4)
            }

            // 選択ボタン
            Button {
                onSelect()
            } label: {
                Text("このテンプレートを使う")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

#Preview("日常Vlog") {
    TemplatePreviewCard(
        template: TemplateDTO(
            id: "daily-vlog",
            name: "1日のVlog",
            description: "朝から夜までの1日を記録するテンプレート",
            referenceVideoUrl: "https://youtube.com/example1",
            explanation: "朝→昼→夜の流れで、日常の何気ない瞬間を切り取ります",
            segments: [
                SegmentDTO(order: 0, startSec: 0, endSec: 10, description: "オープニング"),
                SegmentDTO(order: 1, startSec: 10, endSec: 30, description: "朝の様子"),
                SegmentDTO(order: 2, startSec: 30, endSec: 60, description: "メイン活動")
            ]
        ),
        onSelect: {}
    )
    .padding()
}

#Preview("旅行Vlog") {
    TemplatePreviewCard(
        template: TemplateDTO(
            id: "travel-vlog",
            name: "旅行Vlog",
            description: "旅の思い出を美しく残すテンプレート",
            referenceVideoUrl: "https://youtube.com/example2",
            explanation: "出発→到着→観光→グルメ→帰路の流れで構成",
            segments: [
                SegmentDTO(order: 0, startSec: 0, endSec: 5, description: "出発"),
                SegmentDTO(order: 1, startSec: 5, endSec: 20, description: "到着"),
                SegmentDTO(order: 2, startSec: 20, endSec: 40, description: "観光"),
                SegmentDTO(order: 3, startSec: 40, endSec: 55, description: "グルメ"),
                SegmentDTO(order: 4, startSec: 55, endSec: 60, description: "エンディング")
            ]
        ),
        onSelect: {}
    )
    .padding()
}

#Preview("シンプル") {
    TemplatePreviewCard(
        template: TemplateDTO(
            id: "simple",
            name: "シンプルVlog",
            description: "短くてシンプルなVlog",
            referenceVideoUrl: "",
            explanation: "",
            segments: [
                SegmentDTO(order: 0, startSec: 0, endSec: 15, description: "メイン")
            ]
        ),
        onSelect: {}
    )
    .padding()
}
