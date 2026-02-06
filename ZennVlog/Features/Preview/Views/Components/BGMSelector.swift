import SwiftUI

/// BGM選択モーダル
/// BGMトラック一覧を表示し、試聴・選択機能を提供
struct BGMSelector: View {
    let bgmTracks: [BGMTrack]
    let selectedBGM: BGMTrack?
    let onSelect: (BGMTrack) -> Void
    let onDismiss: () -> Void

    @State private var previewingTrack: BGMTrack?

    var body: some View {
        NavigationStack {
            List(bgmTracks, id: \.id) { track in
                BGMTrackRow(
                    track: track,
                    isSelected: selectedBGM?.id == track.id,
                    isPreviewing: previewingTrack?.id == track.id,
                    onPreview: {
                        if previewingTrack?.id == track.id {
                            previewingTrack = nil
                        } else {
                            previewingTrack = track
                        }
                    },
                    onSelect: {
                        onSelect(track)
                    }
                )
            }
            .navigationTitle("BGM選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

/// BGMトラック行
private struct BGMTrackRow: View {
    let track: BGMTrack
    let isSelected: Bool
    let isPreviewing: Bool
    let onPreview: () -> Void
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 試聴ボタン
            Button {
                onPreview()
            } label: {
                Image(systemName: isPreviewing ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)

            // トラック情報
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.headline)

                Text(track.genre)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(formatDuration(track.duration))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 選択状態
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("選択") {
                    onSelect()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

#Preview {
    let sampleTracks = [
        BGMTrack(id: "1", title: "爽やかな朝", description: "明るく前向きな曲", genre: "Pop", duration: 120, storageUrl: "mock://bgm1", tags: ["明るい"]),
        BGMTrack(id: "2", title: "チルな午後", description: "リラックスした雰囲気", genre: "Lo-Fi", duration: 180, storageUrl: "mock://bgm2", tags: ["リラックス"]),
        BGMTrack(id: "3", title: "エモーショナル", description: "感動的なシーンに", genre: "Cinematic", duration: 240, storageUrl: "mock://bgm3", tags: ["感動"])
    ]

    return BGMSelector(
        bgmTracks: sampleTracks,
        selectedBGM: nil,
        onSelect: { _ in },
        onDismiss: {}
    )
}

#Preview("選択済み") {
    let sampleTracks = [
        BGMTrack(id: "1", title: "爽やかな朝", description: "明るく前向きな曲", genre: "Pop", duration: 120, storageUrl: "mock://bgm1", tags: ["明るい"]),
        BGMTrack(id: "2", title: "チルな午後", description: "リラックスした雰囲気", genre: "Lo-Fi", duration: 180, storageUrl: "mock://bgm2", tags: ["リラックス"])
    ]

    return BGMSelector(
        bgmTracks: sampleTracks,
        selectedBGM: sampleTracks[0],
        onSelect: { _ in },
        onDismiss: {}
    )
}
