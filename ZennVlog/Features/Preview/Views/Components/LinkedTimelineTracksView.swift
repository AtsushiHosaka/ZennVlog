import SwiftUI

struct LinkedTimelineTracksView: View {
    let duration: Double
    let currentTime: Double
    let videoSegments: [VideoTimelineSegment]
    let subtitles: [Subtitle]
    let onSeek: (Double) -> Void
    let onBeginScrub: () -> Void
    let onEndScrub: () -> Void
    let onSubtitleTap: (Subtitle) -> Void
    let onAddSubtitle: () -> Void

    private let pointsPerSecond: CGFloat = 70
    private let videoTrackHeight: CGFloat = 74
    private let subtitleTrackHeight: CGFloat = 62
    private let trackSpacing: CGFloat = 10
    @State private var isScrubbing = false
    @State private var scrubStartTime: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            header

            GeometryReader { proxy in
                let timelineWidth = max(CGFloat(duration) * pointsPerSecond, 240)
                let centerX = proxy.size.width / 2
                let contentOffsetX = centerX - CGFloat(clampedTime(currentTime)) * pointsPerSecond

                ZStack(alignment: .center) {
                    timelineContent(width: timelineWidth)
                        .offset(x: contentOffsetX)

                    playhead
                }
                .clipped()
                .contentShape(Rectangle())
                .gesture(
                    scrubGesture(
                        viewportSize: proxy.size,
                        contentOffsetX: contentOffsetX
                    ),
                    including: .all
                )
            }
            .frame(height: 152)
        }
    }

    private var header: some View {
        HStack {
            Text("タイムライン")
                .font(.subheadline.weight(.semibold))

            Spacer()

            Button {
                onAddSubtitle()
            } label: {
                Label("テロップ追加", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var playhead: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.red)
                .frame(width: 2, height: 130)
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .offset(y: -1)
        }
    }

    private func timelineContent(width: CGFloat) -> some View {
        VStack(spacing: 10) {
            VideoTimelineTrack(
                segments: videoSegments,
                duration: duration,
                pointsPerSecond: pointsPerSecond
            )

            subtitleTrack(width: width)
        }
        .frame(width: width, alignment: .leading)
    }

    private func subtitleTrack(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.tertiarySystemBackground).opacity(0.95))
                .frame(width: width, height: 62)

            ForEach(subtitles, id: \.id) { subtitle in
                Text(subtitle.text)
                    .font(.caption)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 40)
                    .background(Color.accentColor.opacity(0.22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor.opacity(0.8), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .allowsHitTesting(false)
                    .frame(width: subtitleWidth(subtitle))
                    .offset(x: CGFloat(subtitle.startSeconds) * pointsPerSecond, y: 11)
            }
        }
        .frame(width: width, height: 62, alignment: .leading)
    }

    private func subtitleWidth(_ subtitle: Subtitle) -> CGFloat {
        let raw = CGFloat(subtitle.endSeconds - subtitle.startSeconds) * pointsPerSecond
        return max(raw, 56)
    }

    private func scrubGesture(
        viewportSize: CGSize,
        contentOffsetX: CGFloat
    ) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isScrubbing {
                    let translation = value.translation
                    if abs(translation.width) < 0.5, abs(translation.height) < 0.5 {
                        return
                    }
                    isScrubbing = true
                    scrubStartTime = currentTime
                    onBeginScrub()
                }

                let deltaSeconds = Double(-value.translation.width / pointsPerSecond)
                let nextTime = clampedTime(scrubStartTime + deltaSeconds)
                onSeek(nextTime)
            }
            .onEnded { value in
                if !isScrubbing {
                    handleTap(value: value, viewportSize: viewportSize, contentOffsetX: contentOffsetX)
                    return
                }

                guard isScrubbing else { return }
                isScrubbing = false
                onEndScrub()
            }
    }

    private func handleTap(
        value: DragGesture.Value,
        viewportSize: CGSize,
        contentOffsetX: CGFloat
    ) {
        let translation = value.translation
        guard abs(translation.width) < 8, abs(translation.height) < 8 else { return }

        let trackHeight = videoTrackHeight + trackSpacing + subtitleTrackHeight
        let topInset = max(0, (viewportSize.height - trackHeight) / 2)
        let subtitleTop = topInset + videoTrackHeight + trackSpacing
        let subtitleBottom = subtitleTop + subtitleTrackHeight

        let y = value.location.y
        guard y >= subtitleTop, y <= subtitleBottom else { return }

        let tappedTime = clampedTime(Double((value.location.x - contentOffsetX) / pointsPerSecond))
        guard let subtitle = subtitle(at: tappedTime) else { return }
        onSubtitleTap(subtitle)
    }

    private func subtitle(at time: Double) -> Subtitle? {
        let rounded = (time * 100).rounded() / 100
        return subtitles.first { subtitle in
            rounded >= subtitle.startSeconds && rounded < subtitle.endSeconds
        }
    }

    private func clampedTime(_ value: Double) -> Double {
        guard duration > 0 else { return max(0, value) }
        return min(max(0, value), duration)
    }
}

#Preview {
    LinkedTimelineTracksView(
        duration: 40,
        currentTime: 12,
        videoSegments: [
            VideoTimelineSegment(id: 0, order: 0, startSeconds: 0, endSeconds: 8, localFileURL: nil),
            VideoTimelineSegment(id: 1, order: 1, startSeconds: 8, endSeconds: 20, localFileURL: nil),
            VideoTimelineSegment(id: 2, order: 2, startSeconds: 20, endSeconds: 40, localFileURL: nil)
        ],
        subtitles: [
            Subtitle(startSeconds: 1, endSeconds: 4, text: "朝の散歩"),
            Subtitle(startSeconds: 8, endSeconds: 13, text: "駅まで移動"),
            Subtitle(startSeconds: 22, endSeconds: 29, text: "ランチタイム")
        ],
        onSeek: { _ in },
        onBeginScrub: {},
        onEndScrub: {},
        onSubtitleTap: { _ in },
        onAddSubtitle: {}
    )
    .padding()
}
