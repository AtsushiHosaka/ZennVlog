import SwiftUI

/// プロジェクトカードコンポーネント
/// 縦型カード（上：サムネイル、下：情報）
struct ProjectCard: View {
    let project: Project

    var body: some View {
        thumbnailView
            .overlay(alignment: .topLeading) {
                statusBadge
                    .padding(6)
            }
            .overlay(alignment: .bottomLeading) {
                // タイトル・情報オーバーレイ
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.headline)
                        .lineLimit(2)

                    if !project.theme.isEmpty {
                        Text(project.theme)
                            .font(.caption)
                            .lineLimit(1)
                    }

                    Text(relativeTimeString(from: project.updatedAt))
                        .font(.caption2)
                }
                .foregroundColor(.white)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [.black.opacity(0.7), .clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Subviews

    private var thumbnailView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .aspectRatio(9/16, contentMode: .fit)
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
            .background(.ultraThinMaterial)
            .foregroundColor(statusTextColor)
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

    private var statusBackgroundColor: Color {
        switch project.status {
        case .chatting: return .orange
        case .recording: return .accentColor
        case .editing: return .accentColor
        case .completed: return .green
        }
    }

    private var statusTextColor: Color {
        switch project.status {
        case .recording, .editing:
            return .black
        default:
            return statusBackgroundColor
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
    .frame(width: 180)
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
    .frame(width: 180)
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
    .frame(width: 180)
    .padding()
}
