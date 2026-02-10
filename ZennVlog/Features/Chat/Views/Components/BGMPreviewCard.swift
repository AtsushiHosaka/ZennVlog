import SwiftUI

/// BGMプレビューカード
/// 提案されたBGMの情報を表示し、選択可能にする
struct BGMPreviewCard: View {
    let bgm: BGMTrack
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // アイコン
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }

            // BGM情報
            VStack(alignment: .leading, spacing: 4) {
                Text(bgm.title)
                    .font(.headline)
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    Label(bgm.genre, systemImage: "music.quarternote.3")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(formatDuration(Double(bgm.duration)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 選択ボタン/選択済みインジケータ
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            } else {
                Button {
                    onSelect()
                } label: {
                    Text("選択")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
        )
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview("未選択") {
    BGMPreviewCard(
        bgm: BGMTrack(
            id: "1",
            title: "爽やかな朝",
            description: "明るく前向きな曲",
            genre: "Pop",
            duration: 180,
            storageUrl: "mock://bgm/morning.mp3",
            tags: ["明るい"]
        ),
        isSelected: false,
        onSelect: {}
    )
    .padding()
}

#Preview("選択済み") {
    BGMPreviewCard(
        bgm: BGMTrack(
            id: "2",
            title: "チルな午後",
            description: "リラックスした雰囲気",
            genre: "Lo-Fi",
            duration: 240,
            storageUrl: "mock://bgm/afternoon.mp3",
            tags: ["落ち着いた"]
        ),
        isSelected: true,
        onSelect: {}
    )
    .padding()
}

#Preview("長いタイトル") {
    BGMPreviewCard(
        bgm: BGMTrack(
            id: "3",
            title: "夕暮れのビーチでのリラックスタイム",
            description: "リラックスした夏の雰囲気",
            genre: "Acoustic",
            duration: 300,
            storageUrl: "mock://bgm/sunset.mp3",
            tags: ["リラックス"]
        ),
        isSelected: false,
        onSelect: {}
    )
    .padding()
}

#Preview("複数カード") {
    VStack(spacing: 12) {
        BGMPreviewCard(
            bgm: BGMTrack(id: "1", title: "爽やかな朝", description: "明るい曲", genre: "Pop", duration: 180, storageUrl: "", tags: []),
            isSelected: true,
            onSelect: {}
        )
        BGMPreviewCard(
            bgm: BGMTrack(id: "2", title: "チルな午後", description: "落ち着いた曲", genre: "Lo-Fi", duration: 240, storageUrl: "", tags: []),
            isSelected: false,
            onSelect: {}
        )
        BGMPreviewCard(
            bgm: BGMTrack(id: "3", title: "アクティブな夜", description: "元気な曲", genre: "Electronic", duration: 200, storageUrl: "", tags: []),
            isSelected: false,
            onSelect: {}
        )
    }
    .padding()
}
