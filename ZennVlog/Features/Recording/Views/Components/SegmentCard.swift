import SwiftUI

/// タイムラインのセグメントカード
/// サムネイル、チェックマーク、セグメント名を表示
struct SegmentCard: View {
    let segment: Segment
    let isRecorded: Bool
    let isSelected: Bool
    let width: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            // サムネイル領域
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isRecorded ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: max(width, 50), height: 60)

                if isRecorded {
                    // サムネイルプレースホルダー
                    Image(systemName: "video.fill")
                        .foregroundColor(.blue)
                } else {
                    // 未撮影
                    VStack(spacing: 2) {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.gray)
                        Text("撮影")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }

                // 撮影済みマーク
                if isRecorded {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                        Spacer()
                    }
                    .padding(4)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )

            // セグメント番号
            Text("S\(segment.order + 1)")
                .font(.caption2)
                .foregroundColor(isSelected ? .blue : .secondary)
        }
    }
}

#Preview("未撮影") {
    SegmentCard(
        segment: Segment(order: 0, startSeconds: 0, endSeconds: 10, segmentDescription: "オープニング"),
        isRecorded: false,
        isSelected: false,
        width: 80
    )
    .padding()
}

#Preview("撮影済み") {
    SegmentCard(
        segment: Segment(order: 1, startSeconds: 10, endSeconds: 25, segmentDescription: "メインシーン"),
        isRecorded: true,
        isSelected: false,
        width: 100
    )
    .padding()
}

#Preview("選択中") {
    SegmentCard(
        segment: Segment(order: 2, startSeconds: 25, endSeconds: 35, segmentDescription: "エンディング"),
        isRecorded: false,
        isSelected: true,
        width: 70
    )
    .padding()
}

#Preview("タイムライン") {
    HStack(spacing: 4) {
        SegmentCard(
            segment: Segment(order: 0, startSeconds: 0, endSeconds: 5),
            isRecorded: true,
            isSelected: false,
            width: 60
        )
        SegmentCard(
            segment: Segment(order: 1, startSeconds: 5, endSeconds: 15),
            isRecorded: true,
            isSelected: true,
            width: 100
        )
        SegmentCard(
            segment: Segment(order: 2, startSeconds: 15, endSeconds: 25),
            isRecorded: false,
            isSelected: false,
            width: 80
        )
    }
    .padding()
}
