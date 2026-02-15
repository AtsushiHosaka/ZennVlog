import SwiftUI

struct LinkedTimelineTracksView: View {
    let duration: Double
    let currentTime: Double
    let segmentItems: [SegmentTimelineItem]
    let onSeek: (Double) -> Void
    let onBeginScrub: () -> Void
    let onEndScrub: () -> Void
    let onSegmentSubtitleTap: (Int) -> Void

    private let pointsPerSecond: CGFloat = 40
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
                .highPriorityGesture(scrubGesture(), including: .all)
            }
            .frame(height: 152)
        }
    }

    private var header: some View {
        HStack {
            Text("タイムライン")
                .font(.subheadline.weight(.semibold))

            Spacer()
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
                segmentItems: segmentItems,
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

            ForEach(segmentItems) { item in
                Text(item.subtitleText?.isEmpty == false ? (item.subtitleText ?? "") : "未入力")
                    .font(.caption)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 40)
                    .background(item.hasSubtitle ? Color.accentColor.opacity(0.22) : Color.gray.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                item.hasSubtitle ? Color.accentColor.opacity(0.8) : Color.gray.opacity(0.4),
                                style: StrokeStyle(lineWidth: 1, dash: item.hasSubtitle ? [] : [4, 4])
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(width: subtitleWidth(item))
                    .offset(x: CGFloat(item.startSeconds) * pointsPerSecond, y: 11)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSegmentSubtitleTap(item.segmentOrder)
                    }
            }
        }
        .frame(width: width, height: 62, alignment: .leading)
    }

    private func subtitleWidth(_ item: SegmentTimelineItem) -> CGFloat {
        let raw = CGFloat(item.endSeconds - item.startSeconds) * pointsPerSecond
        return max(raw, 56)
    }

    private func scrubGesture() -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if !isScrubbing {
                    isScrubbing = true
                    scrubStartTime = currentTime
                    onBeginScrub()
                }

                let deltaSeconds = Double(-value.translation.width / pointsPerSecond)
                let nextTime = clampedTime(scrubStartTime + deltaSeconds)
                onSeek(nextTime)
            }
            .onEnded { _ in
                guard isScrubbing else { return }
                isScrubbing = false
                onEndScrub()
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
        segmentItems: [
            SegmentTimelineItem(
                id: 0,
                segmentOrder: 0,
                startSeconds: 0,
                endSeconds: 8,
                videoLocalFileURL: nil,
                subtitleId: UUID(),
                subtitleText: "朝の散歩"
            ),
            SegmentTimelineItem(
                id: 1,
                segmentOrder: 1,
                startSeconds: 8,
                endSeconds: 20,
                videoLocalFileURL: nil,
                subtitleId: nil,
                subtitleText: nil
            ),
            SegmentTimelineItem(
                id: 2,
                segmentOrder: 2,
                startSeconds: 20,
                endSeconds: 40,
                videoLocalFileURL: nil,
                subtitleId: UUID(),
                subtitleText: "ランチタイム"
            )
        ],
        onSeek: { _ in },
        onBeginScrub: {},
        onEndScrub: {},
        onSegmentSubtitleTap: { _ in }
    )
    .padding()
}
