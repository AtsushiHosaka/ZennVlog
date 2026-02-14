import SwiftUI
import UIKit

struct CameraPreview: View {
    @ObservedObject var cameraService: CameraService
    @Environment(\.scenePhase) private var scenePhase
//    @ObservedObject var recorder: CameraRecorderService
    
    let segmentDescription: String?
    let guideImage: UIImage?
    let showGuideImage: Bool
    let isLoadingGuideImage: Bool
    
    var body: some View {
        ZStack {
            switch cameraService.permissionState {
            case .authorized:
                CameraPreviewLayerView(session: cameraService.session)
            case .deniedOrRestricted:
                permissionDeniedView
            case .unknown:
                Rectangle().fill(Color.black)
            }
            
            // ガイド画像
            if showGuideImage {
                if let guideImage {
                    Image(uiImage: guideImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .opacity(0.5)
                        .clipped()
                } else if isLoadingGuideImage {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
            }
            
            // セグメント説明
            if let description = segmentDescription,
               !description.isEmpty {
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
                .padding(.top, 80)
            }
        }
        .onAppear {
            if scenePhase == .active {
                cameraService.startIfNeeded()
            }
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                cameraService.startIfNeeded()
            case .inactive:
                // ✅ 何もしない（ここで止めると録画開始と競合しやすい）
                break
            case .background:
                // ✅ バックグラウンドに落ちた時だけ止める
                cameraService.stopSession()
            @unknown default:
                break
            }
        }

//        .onAppear {
//            cameraService.startIfNeeded()
//        }
//        .onDisappear {
//            cameraService.stopSession()
//        }
    }
    
    private var permissionDeniedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("カメラへのアクセスが必要です")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("設定 > このアプリ > カメラ を許可してください")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

//#Preview("通常") {
//    CameraPreview(
//        cameraService: <#CameraService#>,
//        segmentDescription: "朝起きてからの様子を撮影",
//        guideImage: nil,
//        showGuideImage: false,
//        isLoadingGuideImage: false
//    )
//    .aspectRatio(16/9, contentMode: .fit)
//}
//
//#Preview("ガイド読み込み中") {
//    CameraPreview(
//        cameraService: <#CameraService#>,
//        segmentDescription: "カフェでの様子",
//        guideImage: nil,
//        showGuideImage: true,
//        isLoadingGuideImage: true
//    )
//    .aspectRatio(16/9, contentMode: .fit)
//}
//
//#Preview("説明なし") {
//    CameraPreview(
//        cameraService: <#CameraService#>,
//        segmentDescription: nil,
//        guideImage: nil,
//        showGuideImage: false,
//        isLoadingGuideImage: false
//    )
//    .aspectRatio(16/9, contentMode: .fit)
//}
