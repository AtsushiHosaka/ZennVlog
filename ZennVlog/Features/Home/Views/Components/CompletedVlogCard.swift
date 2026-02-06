import SwiftUI

/// 完成したVlogカード
/// サムネイル、プロジェクト名、完成日
struct CompletedVlogCard: View {
    let project: CompletedProjectData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // サムネイル
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(16/9, contentMode: .fit)
                .overlay {
                    ZStack {
                        Image(systemName: "video.fill")
                            .font(.title2)
                            .foregroundColor(.gray)

                        // 完成バッジ
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .background(Circle().fill(.white).padding(-2))
                            }
                            Spacer()
                        }
                        .padding(8)
                    }
                }

            // 情報
            Text(project.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            Text(dateString(from: project.createdAt))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 140)
    }

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

#Preview {
    CompletedVlogCard(
        project: CompletedProjectData(
            projectId: UUID(),
            name: "週末の旅行Vlog",
            status: .completed,
            createdAt: Date().addingTimeInterval(-86400 * 7)
        )
    )
    .padding()
}

#Preview("グリッド表示") {
    ScrollView(.horizontal) {
        HStack(spacing: 12) {
            ForEach(0..<5) { index in
                CompletedVlogCard(
                    project: CompletedProjectData(
                        projectId: UUID(),
                        name: "サンプルVlog \(index + 1)",
                        status: .completed,
                        createdAt: Date().addingTimeInterval(Double(-86400 * index))
                    )
                )
            }
        }
        .padding()
    }
}
