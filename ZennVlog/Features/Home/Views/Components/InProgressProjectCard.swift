import SwiftUI

/// 進行中プロジェクトカード
/// 次に撮るセグメントを強調表示
struct InProgressProjectCard: View {
    let project: InProgressProjectData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // プロジェクト名と進捗
            HStack {
                Text(project.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text("\(project.completedSegments)/\(project.totalSegments)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }

            // 進捗バー
            ProgressView(value: Double(project.completedSegments), total: Double(project.totalSegments))
                .tint(.blue)

            // 次に撮るセグメント（強調）
            VStack(alignment: .leading, spacing: 4) {
                Text("次に撮る")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Image(systemName: "video.fill")
                        .foregroundColor(.blue)

                    Text(project.nextSegmentDescription)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    InProgressProjectCard(
        project: InProgressProjectData(
            projectId: UUID(),
            name: "週末のお出かけVlog",
            nextSegmentOrder: 2,
            nextSegmentDescription: "お気に入りのカフェで一息",
            completedSegments: 2,
            totalSegments: 5
        )
    )
    .padding()
}

#Preview("長い説明") {
    InProgressProjectCard(
        project: InProgressProjectData(
            projectId: UUID(),
            name: "旅行Vlog 〜京都編〜",
            nextSegmentOrder: 3,
            nextSegmentDescription: "清水寺の舞台から眺める京都の街並み。紅葉シーズンの美しさを撮影",
            completedSegments: 3,
            totalSegments: 8
        )
    )
    .padding()
}
