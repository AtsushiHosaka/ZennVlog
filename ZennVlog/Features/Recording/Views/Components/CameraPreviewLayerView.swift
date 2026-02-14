import SwiftUI
import AVFoundation

/// SwiftUI <-> AVCaptureVideoPreviewLayer の橋渡し
struct CameraPreviewLayerView: UIViewRepresentable {
    
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> CameraPreviewHostView {
        let view = CameraPreviewHostView()
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.videoPreviewLayer.session = session
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewHostView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }
}

/// AVCaptureVideoPreviewLayer を保持する UIView
final class CameraPreviewHostView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
