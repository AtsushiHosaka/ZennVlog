import SwiftUI

/// ストック動画表示エリア
/// タイムラインに割り当てていない動画を表示
struct StockVideoArea: View {
    let stockAssets: [VideoAsset]
    let onAssetTap: (VideoAsset) -> Void
    let onAssetDelete: (VideoAsset) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "film.stack")
                    .foregroundColor(.secondary)
                Text("ストック")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(stockAssets.count)件")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            if stockAssets.isEmpty {
                Text("ストック動画はありません")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(stockAssets, id: \.id) { asset in
                            StockVideoCard(asset: asset)
                                .onTapGesture {
                                    onAssetTap(asset)
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        onAssetDelete(asset)
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.tertiarySystemBackground))
    }
}

/// ストック動画カード
private struct StockVideoCard: View {
    let asset: VideoAsset

    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 60, height: 45)
                .overlay {
                    Image(systemName: "video.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

            Text(formatDuration(asset.duration))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func formatDuration(_ duration: Double) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview("アイテムあり") {
    let assets = [
        VideoAsset(segmentOrder: nil, localFileURL: "mock://stock1.mp4", duration: 15),
        VideoAsset(segmentOrder: nil, localFileURL: "mock://stock2.mp4", duration: 30),
        VideoAsset(segmentOrder: nil, localFileURL: "mock://stock3.mp4", duration: 8)
    ]

    return StockVideoArea(
        stockAssets: assets,
        onAssetTap: { _ in },
        onAssetDelete: { _ in }
    )
}

#Preview("空状態") {
    StockVideoArea(
        stockAssets: [],
        onAssetTap: { _ in },
        onAssetDelete: { _ in }
    )
}
