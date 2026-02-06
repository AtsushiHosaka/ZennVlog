import SwiftUI

/// テロップ表示オーバーレイ
/// 動画プレーヤーの下部にテロップを表示
struct SubtitleOverlay: View {
    let text: String

    var body: some View {
        if !text.isEmpty {
            VStack {
                Spacer()

                Text(text)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(4)
                    .padding(.bottom, 20)
            }
        }
    }
}

#Preview("テロップあり") {
    ZStack {
        Color.gray

        SubtitleOverlay(text: "これはサンプルのテロップです")
    }
    .frame(height: 200)
}

#Preview("複数行") {
    ZStack {
        Color.gray

        SubtitleOverlay(text: "1行目のテロップ\n2行目のテロップ")
    }
    .frame(height: 200)
}

#Preview("テロップなし") {
    ZStack {
        Color.gray

        SubtitleOverlay(text: "")
    }
    .frame(height: 200)
}
