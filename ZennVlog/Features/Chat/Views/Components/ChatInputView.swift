import SwiftUI

/// チャット入力エリア
/// テキスト入力、送信ボタン、動画添付機能
struct ChatInputView: View {
    @Binding var text: String
    let isLoading: Bool
    let attachedVideoURL: URL?
    let onSend: () -> Void
    let onAttachVideo: () -> Void
    let onRemoveVideo: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // 添付動画プレビュー
            if let url = attachedVideoURL {
                HStack(spacing: 8) {
                    Image(systemName: "video.fill")
                        .foregroundColor(.blue)

                    Text(url.lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer()

                    Button {
                        onRemoveVideo()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }

            // 入力エリア
            HStack(spacing: 12) {
                // 動画添付ボタン
                Button {
                    onAttachVideo()
                } label: {
                    Image(systemName: "video.badge.plus")
                        .font(.title3)
                        .foregroundColor(.blue)
                }

                // テキスト入力
                TextField("メッセージを入力...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)
                    .lineLimit(1...5)

                // 送信ボタン
                Button {
                    onSend()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(canSend ? .blue : .gray)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color.gray.opacity(0.05))
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }
}

#Preview("空の状態") {
    ChatInputView(
        text: .constant(""),
        isLoading: false,
        attachedVideoURL: nil,
        onSend: {},
        onAttachVideo: {},
        onRemoveVideo: {}
    )
}

#Preview("入力中") {
    ChatInputView(
        text: .constant("旅行のVlogを作りたいです"),
        isLoading: false,
        attachedVideoURL: nil,
        onSend: {},
        onAttachVideo: {},
        onRemoveVideo: {}
    )
}

#Preview("ローディング中") {
    ChatInputView(
        text: .constant("送信中..."),
        isLoading: true,
        attachedVideoURL: nil,
        onSend: {},
        onAttachVideo: {},
        onRemoveVideo: {}
    )
}

#Preview("動画添付済み") {
    ChatInputView(
        text: .constant(""),
        isLoading: false,
        attachedVideoURL: URL(string: "file:///path/to/video.mp4"),
        onSend: {},
        onAttachVideo: {},
        onRemoveVideo: {}
    )
}

#Preview("複数行入力") {
    ChatInputView(
        text: .constant("これは複数行の\nメッセージです\n改行も対応しています"),
        isLoading: false,
        attachedVideoURL: nil,
        onSend: {},
        onAttachVideo: {},
        onRemoveVideo: {}
    )
}
