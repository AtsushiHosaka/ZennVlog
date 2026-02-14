import SwiftUI

/// 固定ヘッド方式でシークするタイムライン
struct SeekTimelineScrubberView: View {
    let duration: Double
    let currentTime: Double
    let onSeek: (Double) -> Void

    private let pointsPerSecond: CGFloat = 70

    var body: some View {
        GeometryReader { geometry in
            let sideInset = geometry.size.width / 2
            let timelineWidth = max(CGFloat(duration) * pointsPerSecond, 1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: sideInset, height: 1)

                    timelineBody(width: timelineWidth)
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: SeekTimelineOffsetPreferenceKey.self,
                                    value: proxy.frame(in: .named("seek_timeline")).minX
                                )
                            }
                        )

                    Color.clear
                        .frame(width: sideInset, height: 1)
                }
            }
            .coordinateSpace(name: "seek_timeline")
            .onPreferenceChange(SeekTimelineOffsetPreferenceKey.self) { minX in
                guard duration > 0 else { return }
                let offset = max(0, min(sideInset - minX, timelineWidth))
                let time = Double(offset / pointsPerSecond)
                onSeek(min(max(time, 0), duration))
            }
            .overlay(alignment: .center) {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 2, height: 44)
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .offset(y: -1)
                }
            }
        }
        .frame(height: 60)
    }

    @ViewBuilder
    private func timelineBody(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.secondarySystemBackground))
                .frame(width: width, height: 52)

            ForEach(0...tickCount, id: \.self) { tick in
                let seconds = Double(tick) / 2
                let xOffset = CGFloat(seconds) * pointsPerSecond
                let isMajor = tick % 2 == 0

                Rectangle()
                    .fill(Color.secondary.opacity(0.7))
                    .frame(width: 1, height: isMajor ? 18 : 10)
                    .offset(x: xOffset, y: 6)

                if isMajor && Int(seconds) % 2 == 0 {
                    Text(formatTime(seconds))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .offset(x: xOffset + 4, y: 26)
                }
            }

            // 外部要因でcurrentTimeが変化したときの位置目安
            Rectangle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 2, height: 52)
                .offset(x: CGFloat(currentTime) * pointsPerSecond, y: 0)
        }
    }

    private var tickCount: Int {
        Int(ceil(duration * 2))
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.down))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

private struct SeekTimelineOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    SeekTimelineScrubberView(
        duration: 40,
        currentTime: 12,
        onSeek: { _ in }
    )
    .padding()
}
