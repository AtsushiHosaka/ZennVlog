import SwiftUI

/// 最近のプロジェクトカード
/// サムネイル、プロジェクト名、更新日時
struct RecentProjectCard: View {
    let project: RecentProjectData

    var body: some View {
        HStack(spacing: 12) {
            // サムネイル
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(16/9, contentMode: .fit)
                .frame(width: 60)
                .overlay {
                    Image(systemName: "video.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

            // 情報
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack {
                    statusBadge

                    Text(relativeTimeString(from: project.updatedAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }

    private var statusBadge: some View {
        Text(statusText)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(4)
    }

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

#Preview {
    RecentProjectCard(
        project: RecentProjectData(
            projectId: UUID(),
            name: "カフェ巡りVlog",
            status: .recording,
            updatedAt: Date().addingTimeInterval(-3600)
        )
    )
    .padding()
}

#Preview("完成済み") {
    RecentProjectCard(
        project: RecentProjectData(
            projectId: UUID(),
            name: "夏休みの思い出",
            status: .completed,
            updatedAt: Date().addingTimeInterval(-86400 * 3)
        )
    )
    .padding()
}
