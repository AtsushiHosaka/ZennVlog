import SwiftUI

/// テロップを時間軸で表示するタイムライン
struct SubtitleTimelineView: View {
    let subtitles: [Subtitle]
    let duration: Double
    let currentTime: Double
    let onSubtitleTap: (Subtitle) -> Void
    let onAddTapped: () -> Void

    private let pointsPerSecond: CGFloat = 70

    var body: some View {
        VStack(spacing: 8) {
            header

            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .frame(width: timelineWidth, height: 60)

                    ForEach(subtitles, id: \.id) { subtitle in
                        subtitleClip(subtitle)
                            .offset(x: xOffset(for: subtitle), y: 10)
                    }

                    Rectangle()
                        .fill(Color.red.opacity(0.9))
                        .frame(width: 2, height: 60)
                        .offset(x: CGFloat(currentTime) * pointsPerSecond)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("テロップ")
                .font(.subheadline)
                .fontWeight(.semibold)

            Spacer()

            Button {
                onAddTapped()
            } label: {
                Label("追加", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func subtitleClip(_ subtitle: Subtitle) -> some View {
        Button {
            onSubtitleTap(subtitle)
        } label: {
            Text(subtitle.text)
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .frame(height: 40)
                .background(Color.accentColor.opacity(0.2))
                .foregroundColor(.primary)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, lineWidth: 1)
                )
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .frame(width: clipWidth(for: subtitle))
    }

    private var timelineWidth: CGFloat {
        max(CGFloat(duration) * pointsPerSecond, 240)
    }

    private func xOffset(for subtitle: Subtitle) -> CGFloat {
        CGFloat(subtitle.startSeconds) * pointsPerSecond
    }

    private func clipWidth(for subtitle: Subtitle) -> CGFloat {
        let raw = CGFloat(subtitle.endSeconds - subtitle.startSeconds) * pointsPerSecond
        return max(raw, 56)
    }
}

#Preview {
    SubtitleTimelineView(
        subtitles: [
            Subtitle(startSeconds: 0, endSeconds: 4, text: "オープニングです"),
            Subtitle(startSeconds: 6, endSeconds: 10, text: "移動シーン"),
            Subtitle(startSeconds: 14, endSeconds: 20, text: "景色のカット")
        ],
        duration: 30,
        currentTime: 8,
        onSubtitleTap: { _ in },
        onAddTapped: {}
    )
    .padding()
}
