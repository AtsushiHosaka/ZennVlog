import SwiftUI

/// 撮影画面
/// テンプレートに沿って動画素材を撮影・追加
struct RecordingView: View {
    @State var viewModel: RecordingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var stockAssetToAssign: VideoAsset?
    @State private var showPreview = false
    @State private var recordingTimer: Timer?
    @State private var remainingSeconds: Double = 0
    
//    @StateObject private var recorder = CameraRecorderService()
    @StateObject private var cameraService = CameraService()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        //        NavigationStack {
        ZStack {
            // カメラプレビュー
            cameraSection
                .aspectRatio(9/16, contentMode: .fit)
            
            VStack(spacing: 0) {
                timeLineSection
                Spacer()
                //                Button {
                //                    if cameraService.isRecording {
                //                        cameraService.stopRecordingTest()
                //                    } else {
                //                        cameraService.startRecordingTest()
                //                    }
                //                } label: {
                //                    Circle()
                //                        .fill(cameraService.isRecording ? .white : .red)
                //                        .frame(width: 80, height: 80)
                //                }
                controlSection
            }
            .opacity(0.8)
            //            .onAppear {
            //                cameraService.onRecordingFinished = { url in
            //                    print("ここで保存処理を書く:", url)
            //                }
            //            }
            // ストック動画エリア -- ココ：カメラロールから追加できるようになったらチェック
            if !viewModel.stockVideoAssets.isEmpty {
                StockVideoArea(
                    stockAssets: viewModel.stockVideoAssets,
                    onAssetTap: { asset in
                        stockAssetToAssign = asset
                    },
                    onAssetDelete: { asset in
                        Task {
                            await viewModel.deleteStockAsset(asset)
                        }
                    }
                )
            }
            
            Spacer()
            
        }
        .navigationTitle(viewModel.project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("編集") {
                    showPreview = true
                }
                .disabled(!viewModel.canProceedToPreview)
            }
        }
        .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .confirmationDialog(
            "セグメントに割り当て",
            isPresented: .init(
                get: { stockAssetToAssign != nil },
                set: { if !$0 { stockAssetToAssign = nil } }
            ),
            titleVisibility: .visible
        ) {
            ForEach(viewModel.segments.filter { segment in
                !viewModel.isSegmentRecorded(segment.order)
            }, id: \.id) { segment in
                Button("セグメント\(segment.order + 1): \(segment.segmentDescription)") {
                    if let asset = stockAssetToAssign {
                        Task {
                            await viewModel.assignStockToSegment(asset, segmentOrder: segment.order)
                        }
                    }
                    stockAssetToAssign = nil
                }
            }
            Button("キャンセル", role: .cancel) {
                stockAssetToAssign = nil
            }
        }
        .navigationDestination(isPresented: $showPreview) {
            let container = DIContainer.shared
            PreviewView(viewModel: PreviewViewModel(
                project: viewModel.project,
                exportVideoUseCase: ExportVideoUseCase(repository: container.projectRepository),
                fetchBGMTracksUseCase: FetchBGMTracksUseCase(repository: container.bgmRepository),
                saveSubtitleUseCase: SaveSubtitleUseCase(repository: container.projectRepository),
                downloadBGMUseCase: DownloadBGMUseCase(repository: container.bgmRepository)
            ))
        }
//        .onAppear {
//            if scenePhase == .active {
//                cameraService.startIfNeeded()
//            }
//            
//            cameraService.onRecordingFinished = { url, duration in
//                Task { await viewModel.saveRecordedVideo(localFileURL: url.path, duration: duration) }
//            }
//        }
        .onAppear {
            if scenePhase == .active {
                cameraService.startIfNeeded()
            }
        }
        .onReceive(cameraService.$recordingResult.compactMap { $0 }) { result in
            Task {
                await viewModel.saveRecordedVideo(
                    localFileURL: result.url.path,
                    duration: result.duration
                )
            }
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                cameraService.startIfNeeded()
            case .background:
                // ✅録画中は stopSession しない（finish が飛ばなくなる典型原因）
                if !cameraService.isRecording {
                    cameraService.stopSession()
                } else {
                    cameraService.stopRecording()
                }
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        
        //        }
    }
    
    private var cameraSection: some View {
        CameraPreview(
            cameraService: cameraService,
            segmentDescription: viewModel.currentSegment?.segmentDescription,
            guideImage: viewModel.guideImage,
            showGuideImage: viewModel.showGuideImage,
            isLoadingGuideImage: viewModel.isLoadingGuideImage
        )
    }
    
    private var timeLineSection: some View {
        TimelineView(
            segments: viewModel.segments,
            videoAssets: viewModel.videoAssets,
            currentSegmentIndex: viewModel.currentSegmentIndex,
            totalWidth: 300,
            onSegmentTap: { order in
                if let index = viewModel.segments.firstIndex(where: { $0.order == order }) {
                    viewModel.selectSegment(at: index)
                }
            },
            onSegmentDelete: { order in
                Task {
                    await viewModel.deleteVideoAsset(for: order)
                }
            }
        )
    }
    
    // MARK: - Sections
    
    private var controlSection: some View {
        VStack(spacing: 16) {
            // ガイド表示トグル
            HStack {
                
                Spacer()
                
                // 撮影時間表示
                Text(formatTime(max(0, remainingSeconds)))
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundColor(.red)
                
            }
            
            // 撮影ボタン
            RecordButtonWithProgress(
                isRecording: viewModel.isRecording,
                progress: recordingProgress,
                canRecord: canRecord && !cameraService.isStartingRecording,
                onTap: {
                    if cameraService.isRecording {
                        stopRecordingFlow()
                    } else {
                        startRecordingFlow()
                    }
                }
            )
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
    
    private var currentSegmentDuration: Double {
        guard let seg = viewModel.currentSegment else { return 0 }
        let d = seg.endSeconds - seg.startSeconds
        return max(0, d)
    }
    
    private func startRecordingFlow() {
        guard canRecord else { return }
        
        // 初期化
        remainingSeconds = currentSegmentDuration
        
        // 既存タイマー停止
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // 録画開始
        viewModel.startRecording()
        cameraService.startRecording()
        
        // Timer開始（0.1秒刻み）
        let t = Timer(timeInterval: 0.1, repeats: true) { _ in
            // 既に止まってるなら何もしない
            guard cameraService.isRecording else { return }
            
            remainingSeconds = max(0, remainingSeconds - 0.1)
            
            // 進捗用（必要なら）
            viewModel.recordingDuration = currentSegmentDuration - remainingSeconds
            
            if remainingSeconds <= 0 {
                stopRecordingFlow() // 自動停止
            }
        }
        
        recordingTimer = t
        RunLoop.main.add(t, forMode: .common)
    }
    
    private func stopRecordingFlow() {
        // Timer停止が先（stop連打対策）
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // 既に止まっててもOKなように
        if cameraService.isRecording {
            cameraService.stopRecording()
        }
        if viewModel.isRecording {
            viewModel.stopRecording()
        }
    }

    
    // MARK: - Helpers
    
    private var canRecord: Bool {
        guard let currentSegment = viewModel.currentSegment else { return false }
        return viewModel.canRecord(for: currentSegment.order)
        //        && cameraService.permissionState == .authorized
        //        && cameraService.isReady
    }
    
    private var recordingProgress: Double {
        guard let currentSegment = viewModel.currentSegment else { return 0 }
        let segmentDuration = currentSegment.endSeconds - currentSegment.startSeconds
        guard segmentDuration > 0 else { return 0 }
        return viewModel.recordingDuration / segmentDuration
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Previews

#Preview("通常") {
    let container = DIContainer.preview
    let template = Template(
        segments: [
            Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング"),
            Segment(order: 1, startSeconds: 5, endSeconds: 15, segmentDescription: "朝の様子"),
            Segment(order: 2, startSeconds: 15, endSeconds: 30, segmentDescription: "昼の活動")
        ]
    )
    let project = Project(
        name: "週末のお出かけVlog",
        theme: "日常",
        template: template,
        videoAssets: [
            VideoAsset(segmentOrder: 0, localFileURL: "mock://video1.mp4", duration: 5)
        ],
        status: .recording
    )
    let viewModel = RecordingViewModel(
        project: project,
        saveVideoAssetUseCase: SaveVideoAssetUseCase(repository: container.projectRepository),
        generateGuideImageUseCase: GenerateGuideImageUseCase(repository: container.imagenRepository),
        analyzeVideoUseCase: AnalyzeVideoUseCase(repository: container.geminiRepository),
        trimVideoUseCase: TrimVideoUseCase(),
        deleteVideoAssetUseCase: DeleteVideoAssetUseCase(repository: container.projectRepository),
        photoLibraryService: container.photoLibraryService
    )
    RecordingView(viewModel: viewModel)
}

#Preview("撮影中") {
    RecordingPreviewWrapper()
}

private struct RecordingPreviewWrapper: View {
    @State private var viewModel: RecordingViewModel
    
    init() {
        let container = DIContainer.preview
        let project = Project(
            name: "テストプロジェクト",
            template: Template(
                segments: [
                    Segment(order: 0, startSeconds: 0, endSeconds: 10, segmentDescription: "テストセグメント")
                ]
            )
        )
        let vm = RecordingViewModel(
            project: project,
            saveVideoAssetUseCase: SaveVideoAssetUseCase(repository: container.projectRepository),
            generateGuideImageUseCase: GenerateGuideImageUseCase(repository: container.imagenRepository),
            analyzeVideoUseCase: AnalyzeVideoUseCase(repository: container.geminiRepository),
            trimVideoUseCase: TrimVideoUseCase(),
            deleteVideoAssetUseCase: DeleteVideoAssetUseCase(repository: container.projectRepository),
            photoLibraryService: container.photoLibraryService
        )
        vm.isRecording = true
        vm.recordingDuration = 5.5
        _viewModel = State(wrappedValue: vm)
    }
    
    var body: some View {
        RecordingView(viewModel: viewModel)
    }
}

#Preview("全撮影完了") {
    let container = DIContainer.preview
    let template = Template(
        segments: [
            Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "セグメント1"),
            Segment(order: 1, startSeconds: 5, endSeconds: 10, segmentDescription: "セグメント2")
        ]
    )
    let project = Project(
        name: "完了プロジェクト",
        template: template,
        videoAssets: [
            VideoAsset(segmentOrder: 0, localFileURL: "mock://video1.mp4", duration: 5),
            VideoAsset(segmentOrder: 1, localFileURL: "mock://video2.mp4", duration: 5)
        ],
        status: .recording
    )
    let viewModel = RecordingViewModel(
        project: project,
        saveVideoAssetUseCase: SaveVideoAssetUseCase(repository: container.projectRepository),
        generateGuideImageUseCase: GenerateGuideImageUseCase(repository: container.imagenRepository),
        analyzeVideoUseCase: AnalyzeVideoUseCase(repository: container.geminiRepository),
        trimVideoUseCase: TrimVideoUseCase(),
        deleteVideoAssetUseCase: DeleteVideoAssetUseCase(repository: container.projectRepository),
        photoLibraryService: container.photoLibraryService
    )
    RecordingView(viewModel: viewModel)
}
