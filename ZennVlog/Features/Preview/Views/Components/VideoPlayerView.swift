import AVFoundation
import SwiftUI

/// 動画プレーヤーコンポーネント
/// AVPlayerLayerをSwiftUIでラップしたUIViewRepresentable
struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer?

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.player = player
    }
}

/// AVPlayerLayerを管理するUIView
class PlayerUIView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
            playerLayer.videoGravity = .resizeAspect
        }
    }
}

// MARK: - Previews

#Preview("プレイヤー") {
    VideoPlayerView(player: nil)
        .aspectRatio(16/9, contentMode: .fit)
        .background(Color.black)
}

#Preview("16:9アスペクト比") {
    VStack {
        VideoPlayerView(player: nil)
            .aspectRatio(16/9, contentMode: .fit)
            .background(Color.black)
            .cornerRadius(8)
            .padding()

        Text("動画プレーヤー")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}
