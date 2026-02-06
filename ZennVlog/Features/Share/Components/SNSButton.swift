import SwiftUI

/// SNS共有ボタンの種類
enum SNSType: String, CaseIterable {
    case tiktok
    case instagram
    case x
    case more

    /// 表示名
    var displayName: String {
        switch self {
        case .tiktok: return "TikTok"
        case .instagram: return "Instagram"
        case .x: return "X"
        case .more: return "その他"
        }
    }

    /// アイコン名（SF Symbols）
    var iconName: String {
        switch self {
        case .tiktok: return "play.rectangle.fill"
        case .instagram: return "camera.fill"
        case .x: return "bubble.left.fill"
        case .more: return "square.and.arrow.up"
        }
    }

    /// ブランドカラー
    var brandColor: Color {
        switch self {
        case .tiktok: return Color(red: 0.0, green: 0.0, blue: 0.0)
        case .instagram: return Color(red: 0.88, green: 0.19, blue: 0.42)
        case .x: return Color(red: 0.0, green: 0.0, blue: 0.0)
        case .more: return Color.gray
        }
    }
}

/// SNS共有ボタンコンポーネント
/// 各SNSのブランドカラーを持つ円形アイコンボタン
struct SNSButton: View {
    let type: SNSType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(type.brandColor)
                        .frame(width: 60, height: 60)

                    Image(systemName: type.iconName)
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }

                Text(type.displayName)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview("TikTok") {
    SNSButton(type: .tiktok, action: {})
        .padding()
}

#Preview("Instagram") {
    SNSButton(type: .instagram, action: {})
        .padding()
}

#Preview("X") {
    SNSButton(type: .x, action: {})
        .padding()
}

#Preview("その他") {
    SNSButton(type: .more, action: {})
        .padding()
}

#Preview("全ボタン") {
    HStack(spacing: 24) {
        ForEach(SNSType.allCases, id: \.self) { type in
            SNSButton(type: type, action: {})
        }
    }
    .padding()
}
