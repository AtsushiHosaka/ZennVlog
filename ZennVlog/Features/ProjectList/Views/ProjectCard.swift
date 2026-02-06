import SwiftUI

/// プロジェクトカードコンポーネント
/// 横型カード（左：サムネイル、右：情報）
struct ProjectCard: View {
    let project: Project

    var body: some View {
        HStack(spacing: 12) {
            // サムネイル（16:9角丸）
            thumbnailView

            // 情報
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.headline)
                    .lineLimit(1)

                if !project.theme.isEmpty {
                    Text(project.theme)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                HStack {
                    statusBadge
                    Spacer()
                    Text(relativeTimeString(from: project.updatedAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Subviews

    private var thumbnailView: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.3))
            .aspectRatio(16/9, contentMode: .fit)
            .frame(width: 80)
            .overlay {
                Image(systemName: "video.fill")
                    .foregroundColor(.gray)
            }
    }

    private var statusBadge: some View {
        Text(statusText)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(4)
    }

    // MARK: - Helpers

    private var statusText: String {
        switch project.status {
        case .chatting: return "会話中"
        case .recording: return "撮影中"
        case .editing: return "編集中"
        case .completed: return "完成"
        }
    }

    private var statusColor: Color {
        switch project.status {
        case .chatting: return .orange
        case .recording: return .blue
        case .editing: return .purple
        case .completed: return .green
        }
    }

    private func relativeTimeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview("通常") {
    ProjectCard(
        project: Project(
            name: "週末のお出かけVlog",
            theme: "旅行",
            status: .recording,
            updatedAt: Date().addingTimeInterval(-3600)
        )
    )
    .padding()
}

#Preview("完成済み") {
    ProjectCard(
        project: Project(
            name: "カフェ巡りVlog",
            theme: "グルメ",
            status: .completed,
            updatedAt: Date().addingTimeInterval(-86400)
        )
    )
    .padding()
}

#Preview("長いタイトル") {
    ProjectCard(
        project: Project(
            name: "これはとても長いプロジェクト名のサンプルです",
            theme: "日常系Vlogテスト",
            status: .editing,
            updatedAt: Date()
        )
    )
    .padding()
}
