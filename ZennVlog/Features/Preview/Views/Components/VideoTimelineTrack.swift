import SwiftUI
import UIKit

struct VideoTimelineTrack: View {
    let segmentItems: [SegmentTimelineItem]
    let duration: Double
    let pointsPerSecond: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.secondarySystemBackground).opacity(0.95))
                .frame(width: timelineWidth, height: 74)

            ForEach(segmentItems) { item in
                VideoTimelineSegmentCell(localFileURL: item.videoLocalFileURL, label: "S\(item.segmentOrder + 1)")
                    .frame(width: width(for: item), height: 62)
                    .offset(x: xOffset(for: item), y: 6)
            }
        }
        .frame(width: timelineWidth, height: 74, alignment: .leading)
    }

    private var timelineWidth: CGFloat {
        max(CGFloat(duration) * pointsPerSecond, 240)
    }

    private func xOffset(for item: SegmentTimelineItem) -> CGFloat {
        CGFloat(item.startSeconds) * pointsPerSecond
    }

    private func width(for item: SegmentTimelineItem) -> CGFloat {
        max(CGFloat(item.duration) * pointsPerSecond, 50)
    }
}

private struct VideoTimelineSegmentCell: View {
    let localFileURL: String?
    let label: String

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else {
                    ZStack {
                        Color.black.opacity(0.08)

                        VStack(spacing: 4) {
                            Image(systemName: "video.slash")
                                .font(.caption)
                            Text("No Thumb")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }

            Text(label)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .task(id: localFileURL) {
            thumbnail = await VideoThumbnailProvider.shared.thumbnail(for: localFileURL)
        }
    }
}

#Preview {
    VideoTimelineTrack(
        segmentItems: [
            SegmentTimelineItem(
                id: 0,
                segmentOrder: 0,
                startSeconds: 0,
                endSeconds: 4,
                videoLocalFileURL: nil,
                subtitleId: nil,
                subtitleText: nil
            ),
            SegmentTimelineItem(
                id: 1,
                segmentOrder: 1,
                startSeconds: 4,
                endSeconds: 11,
                videoLocalFileURL: nil,
                subtitleId: nil,
                subtitleText: "移動"
            ),
            SegmentTimelineItem(
                id: 2,
                segmentOrder: 2,
                startSeconds: 11,
                endSeconds: 18,
                videoLocalFileURL: nil,
                subtitleId: nil,
                subtitleText: nil
            )
        ],
        duration: 18,
        pointsPerSecond: 36
    )
    .padding()
}
