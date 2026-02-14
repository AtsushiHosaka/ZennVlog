import SwiftUI

/// プレビュー上のテロップオーバーレイ
/// 表示中のテロップのみドラッグして位置を調整できる
struct SubtitleOverlay: View {
    let subtitle: Subtitle?
    let bottomBlockedInset: CGFloat
    let onDragStart: () -> Void
    let onDragEnd: () -> Void
    let onPositionCommit: (UUID, Double, Double) -> Void

    @State private var textSize: CGSize = .zero
    @State private var currentPoint: CGPoint = .zero
    @State private var dragStartPoint: CGPoint?
    @State private var currentSubtitleId: UUID?
    @State private var isDragging = false

    var body: some View {
        GeometryReader { proxy in
            if let subtitle, !subtitle.text.isEmpty {
                Text(subtitle.text)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .readSize { size in
                        textSize = size
                        if currentSubtitleId != subtitle.id || currentPoint == .zero {
                            resetCurrentPoint(for: subtitle, in: proxy.size)
                        }
                    }
                    .position(currentPoint == .zero ? point(from: subtitle, in: proxy.size) : currentPoint)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if dragStartPoint == nil {
                                    dragStartPoint = currentPoint == .zero ? point(from: subtitle, in: proxy.size) : currentPoint
                                    isDragging = true
                                    onDragStart()
                                }

                                let origin = dragStartPoint ?? point(from: subtitle, in: proxy.size)
                                let proposed = CGPoint(
                                    x: origin.x + value.translation.width,
                                    y: origin.y + value.translation.height
                                )
                                currentPoint = clamped(proposed, in: proxy.size)
                            }
                            .onEnded { _ in
                                defer {
                                    dragStartPoint = nil
                                    if isDragging {
                                        isDragging = false
                                        onDragEnd()
                                    }
                                }

                                guard proxy.size.width > 0, proxy.size.height > 0 else { return }

                                let clampedPoint = clamped(currentPoint, in: proxy.size)
                                currentPoint = clampedPoint

                                let ratioX = clampedPoint.x / proxy.size.width
                                let ratioY = clampedPoint.y / proxy.size.height
                                onPositionCommit(subtitle.id, ratioX, ratioY)
                            }
                    )
                    .onAppear {
                        resetCurrentPoint(for: subtitle, in: proxy.size)
                    }
                    .onChange(of: subtitle.id) { _, _ in
                        resetCurrentPoint(for: subtitle, in: proxy.size)
                    }
                    .onChange(of: subtitle.positionXRatio) { _, _ in
                        if !isDragging {
                            resetCurrentPoint(for: subtitle, in: proxy.size)
                        }
                    }
                    .onChange(of: subtitle.positionYRatio) { _, _ in
                        if !isDragging {
                            resetCurrentPoint(for: subtitle, in: proxy.size)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func resetCurrentPoint(for subtitle: Subtitle, in size: CGSize) {
        currentSubtitleId = subtitle.id
        currentPoint = point(from: subtitle, in: size)
        dragStartPoint = nil
    }

    private func point(from subtitle: Subtitle, in size: CGSize) -> CGPoint {
        guard size.width > 0, size.height > 0 else { return .zero }

        let raw = CGPoint(
            x: size.width * subtitle.positionXRatio,
            y: size.height * subtitle.positionYRatio
        )
        return clamped(raw, in: size)
    }

    private func clamped(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let blockedInset = max(0, bottomBlockedInset)
        let halfWidth = max(textSize.width / 2, 24)
        let halfHeight = max(textSize.height / 2, 18)

        let minX = halfWidth
        let maxX = max(minX, size.width - halfWidth)
        let minY = halfHeight
        let maxY = max(minY, size.height - blockedInset - halfHeight)

        return CGPoint(
            x: min(max(point.x, minX), maxX),
            y: min(max(point.y, minY), maxY)
        )
    }
}

private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

private extension View {
    func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: proxy.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.4)

        SubtitleOverlay(
            subtitle: Subtitle(startSeconds: 0, endSeconds: 3, text: "これはサンプルのテロップです"),
            bottomBlockedInset: 100,
            onDragStart: {},
            onDragEnd: {},
            onPositionCommit: { _, _, _ in }
        )
    }
    .frame(height: 280)
}
