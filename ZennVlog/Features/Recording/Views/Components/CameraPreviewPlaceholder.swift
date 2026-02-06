import SwiftUI

/// カメラプレビュー（プレースホルダー）
/// 実際のAVCaptureSessionは後で実装
struct CameraPreviewPlaceholder: View {
    let segmentDescription: String?
    let guideImage: UIImage?
    let showGuideImage: Bool
    let isLoadingGuideImage: Bool

    var body: some View {
        ZStack {
            // カメラプレビュー背景
            Rectangle()
                .fill(Color.black)

            // プレースホルダー
            VStack(spacing: 12) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)

                Text("カメラプレビュー")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            // ガイド画像オーバーレイ
            if showGuideImage {
                if let guideImage = guideImage {
                    Image(uiImage: guideImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .opacity(0.5)
                } else if isLoadingGuideImage {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }

            // セグメント説明文オーバーレイ
            if let description = segmentDescription, !description.isEmpty {
                VStack {
                    Text(description)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        .padding(.top, 20)

                    Spacer()
                }
            }
        }
    }
}

#Preview("通常") {
    CameraPreviewPlaceholder(
        segmentDescription: "朝起きてからの様子を撮影",
        guideImage: nil,
        showGuideImage: false,
        isLoadingGuideImage: false
    )
    .aspectRatio(16/9, contentMode: .fit)
}

#Preview("ガイド読み込み中") {
    CameraPreviewPlaceholder(
        segmentDescription: "カフェでの様子",
        guideImage: nil,
        showGuideImage: true,
        isLoadingGuideImage: true
    )
    .aspectRatio(16/9, contentMode: .fit)
}

#Preview("説明なし") {
    CameraPreviewPlaceholder(
        segmentDescription: nil,
        guideImage: nil,
        showGuideImage: false,
        isLoadingGuideImage: false
    )
    .aspectRatio(16/9, contentMode: .fit)
}
