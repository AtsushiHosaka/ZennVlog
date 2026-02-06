import SwiftUI

/// トリム編集画面
/// フォトライブラリから選択した動画のトリム範囲を設定する
struct TrimEditorView: View {
    let videoURL: URL
    let videoScenes: [(timestamp: Double, description: String)]
    let segmentDuration: Double
    let totalVideoDuration: Double
    @Binding var trimStartSeconds: Double
    let onConfirm: (Double) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 動画プレビュー
                videoPreviewSection

                // シーン説明リスト
                sceneListSection

                // トリムスライダー
                trimSliderSection
            }
            .navigationTitle("トリム編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("確定") {
                        onConfirm(trimStartSeconds)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Sections

    private var videoPreviewSection: some View {
        ZStack {
            Rectangle()
                .fill(Color.black)
                .aspectRatio(16/9, contentMode: .fit)

            Image(systemName: "play.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.7))

            // 現在のトリム位置表示
            VStack {
                Spacer()
                HStack {
                    Text(formatTime(trimStartSeconds))
                    Text("〜")
                    Text(formatTime(trimStartSeconds + segmentDuration))
                }
                .font(.caption)
                .monospacedDigit()
                .foregroundColor(.white)
                .padding(8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(6)
                .padding(.bottom, 8)
            }
        }
    }

    private var sceneListSection: some View {
        Group {
            if videoScenes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.justify.left")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("シーン情報なし")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                List {
                    ForEach(Array(videoScenes.enumerated()), id: \.offset) { _, scene in
                        Button {
                            withAnimation {
                                trimStartSeconds = clampTrimStart(scene.timestamp)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Text(formatTime(scene.timestamp))
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                                    .frame(width: 44, alignment: .trailing)

                                Text(scene.description)
                                    .font(.body)
                                    .foregroundColor(.primary)

                                Spacer()

                                if isSceneInRange(scene.timestamp) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var trimSliderSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("開始位置")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatTime(trimStartSeconds))
                    .font(.subheadline)
                    .monospacedDigit()
            }

            Slider(
                value: $trimStartSeconds,
                in: 0...maxTrimStart
            )

            HStack {
                Text(formatTime(0))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatTime(totalVideoDuration))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }

    // MARK: - Helpers

    private var maxTrimStart: Double {
        max(totalVideoDuration - segmentDuration, 0)
    }

    private func clampTrimStart(_ value: Double) -> Double {
        min(max(value, 0), maxTrimStart)
    }

    private func isSceneInRange(_ timestamp: Double) -> Bool {
        timestamp >= trimStartSeconds && timestamp < trimStartSeconds + segmentDuration
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Previews

#Preview("通常") {
    TrimEditorView(
        videoURL: URL(string: "mock://video.mp4")!,
        videoScenes: [
            (timestamp: 0.0, description: "人物が画面に映っている"),
            (timestamp: 5.0, description: "屋外の風景"),
            (timestamp: 12.0, description: "食事のシーン")
        ],
        segmentDuration: 5.0,
        totalVideoDuration: 20.0,
        trimStartSeconds: .constant(0.0),
        onConfirm: { _ in },
        onCancel: {}
    )
}

#Preview("シーンなし") {
    TrimEditorView(
        videoURL: URL(string: "mock://video.mp4")!,
        videoScenes: [],
        segmentDuration: 10.0,
        totalVideoDuration: 30.0,
        trimStartSeconds: .constant(5.0),
        onConfirm: { _ in },
        onCancel: {}
    )
}

#Preview("長い動画") {
    TrimEditorView(
        videoURL: URL(string: "mock://long_video.mp4")!,
        videoScenes: [
            (timestamp: 0.0, description: "イントロダクション"),
            (timestamp: 15.0, description: "準備シーン"),
            (timestamp: 30.0, description: "調理開始"),
            (timestamp: 45.0, description: "盛り付け"),
            (timestamp: 60.0, description: "完成品の紹介"),
            (timestamp: 75.0, description: "実食シーン"),
            (timestamp: 90.0, description: "感想"),
            (timestamp: 100.0, description: "エンディング")
        ],
        segmentDuration: 15.0,
        totalVideoDuration: 120.0,
        trimStartSeconds: .constant(30.0),
        onConfirm: { _ in },
        onCancel: {}
    )
}
