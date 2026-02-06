import SwiftUI

/// 動画添付ボタン
/// フォトライブラリから動画を選択
struct VideoAttachmentButton: View {
    let attachedURL: URL?
    let onAttach: () -> Void
    let onRemove: () -> Void

    var body: some View {
        if let url = attachedURL {
            // 添付済み状態
            HStack(spacing: 8) {
                Image(systemName: "video.fill")
                    .foregroundColor(.blue)

                Text(url.lastPathComponent)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        } else {
            // 未添付状態
            Button {
                onAttach()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "video.badge.plus")
                    Text("動画を添付")
                        .font(.subheadline)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}

#Preview("未添付") {
    VideoAttachmentButton(
        attachedURL: nil,
        onAttach: {},
        onRemove: {}
    )
    .padding()
}

#Preview("添付済み") {
    VideoAttachmentButton(
        attachedURL: URL(string: "file:///path/to/video.mp4")!,
        onAttach: {},
        onRemove: {}
    )
    .padding()
}

#Preview("長いファイル名") {
    VideoAttachmentButton(
        attachedURL: URL(string: "file:///path/to/very_long_video_filename_2024.mp4")!,
        onAttach: {},
        onRemove: {}
    )
    .padding()
}
