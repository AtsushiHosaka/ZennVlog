import SwiftUI

/// プレビュー用タイムライン（読み取り専用）
/// セグメント選択とシーク機能を提供
struct PreviewTimeline: View {
    let segments: [Segment]
    let currentTime: Double
    let onSegmentTap: (Int) -> Void

    private let totalWidth: CGFloat = 300

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ZStack(alignment: .leading) {
                // セグメントカード
                HStack(spacing: 4) {
                    ForEach(segments, id: \.id) { segment in
                        PreviewSegmentCard(
                            segment: segment,
                            width: segmentWidth(for: segment)
                        )
                        .onTapGesture {
                            onSegmentTap(segment.order)
                        }
                    }
                }

                // 再生位置インジケータ
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2)
                    .frame(height: 70)
                    .offset(x: offsetForTime(currentTime))
            }
            .padding(.horizontal)
        }
        .frame(height: 80)
    }

    // MARK: - Helpers

    private var totalDuration: Double {
        segments.reduce(0.0) { $0 + ($1.endSeconds - $1.startSeconds) }
    }

    private func segmentWidth(for segment: Segment) -> CGFloat {
        guard totalDuration > 0 else { return 0 }
        let segmentDuration = segment.endSeconds - segment.startSeconds
        return CGFloat(segmentDuration / totalDuration) * totalWidth
    }

    private func offsetForTime(_ time: Double) -> CGFloat {
        guard totalDuration > 0 else { return 0 }
        return CGFloat(time / totalDuration) * (totalWidth + CGFloat(segments.count - 1) * 4)
    }
}

/// セグメントカード（読み取り専用）
private struct PreviewSegmentCard: View {
    let segment: Segment
    let width: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            // サムネイル領域
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.3))
                .frame(width: max(width, 40), height: 50)
                .overlay {
                    Image(systemName: "video.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

            // タイムコード
            Text(formatTime(segment.startSeconds))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
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

    return PreviewTimeline(
        segments: segments,
        currentTime: 20.0,
        onSegmentTap: { _ in }
    )
    .padding()
    .background(Color.black.opacity(0.05))
}

#Preview("最初") {
    let segments = [
        Segment(order: 0, startSeconds: 0, endSeconds: 10, segmentDescription: "セグメント1"),
        Segment(order: 1, startSeconds: 10, endSeconds: 20, segmentDescription: "セグメント2")
    ]

    return PreviewTimeline(
        segments: segments,
        currentTime: 0,
        onSegmentTap: { _ in }
    )
    .padding()
}
