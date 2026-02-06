import SwiftUI

/// Premiere Proライクなタイムライン
/// セグメントカードを横スクロールで表示
struct TimelineView: View {
    let segments: [Segment]
    let videoAssets: [VideoAsset]
    let currentSegmentIndex: Int
    let totalWidth: CGFloat
    let onSegmentTap: (Int) -> Void
    let onSegmentDelete: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { proxy in
                HStack(spacing: 4) {
                    ForEach(segments, id: \.id) { segment in
                        SegmentCard(
                            segment: segment,
                            isRecorded: isRecorded(segment.order),
                            isSelected: segment.order == currentSegmentIndex,
                            width: segmentWidth(for: segment)
                        )
                        .id(segment.order)
                        .onTapGesture {
                            onSegmentTap(segment.order)
                        }
                        .contextMenu {
                            if isRecorded(segment.order) {
                                Button(role: .destructive) {
                                    onSegmentDelete(segment.order)
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .onChange(of: currentSegmentIndex) { _, newValue in
                    withAnimation {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
        .frame(height: 90)
        .background(Color(UIColor.secondarySystemBackground))
    }

    // MARK: - Helpers

    private func isRecorded(_ segmentOrder: Int) -> Bool {
        videoAssets.contains { $0.segmentOrder == segmentOrder }
    }

    private func segmentWidth(for segment: Segment) -> CGFloat {
        let totalDuration = segments.reduce(0.0) { total, seg in
            total + (seg.endSeconds - seg.startSeconds)
        }
        guard totalDuration > 0 else { return 60 }

        let segmentDuration = segment.endSeconds - segment.startSeconds
        return max(totalWidth * CGFloat(segmentDuration / totalDuration), 50)
    }
}

#Preview {
    let segments = [
        Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング"),
        Segment(order: 1, startSeconds: 5, endSeconds: 15, segmentDescription: "朝の様子"),
        Segment(order: 2, startSeconds: 15, endSeconds: 30, segmentDescription: "昼の活動"),
        Segment(order: 3, startSeconds: 30, endSeconds: 45, segmentDescription: "夜のシーン"),
        Segment(order: 4, startSeconds: 45, endSeconds: 50, segmentDescription: "エンディング")
    ]

    let videoAssets = [
        VideoAsset(segmentOrder: 0, localFileURL: "mock://video1.mp4", duration: 5),
        VideoAsset(segmentOrder: 1, localFileURL: "mock://video2.mp4", duration: 10)
    ]

    return TimelineView(
        segments: segments,
        videoAssets: videoAssets,
        currentSegmentIndex: 2,
        totalWidth: 300,
        onSegmentTap: { _ in },
        onSegmentDelete: { _ in }
    )
}
