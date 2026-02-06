import SwiftUI

/// 撮影画面
/// テンプレートに沿って動画素材を撮影・追加
struct RecordingView: View {
    @State var viewModel: RecordingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var stockAssetToAssign: VideoAsset?
    @State private var showPreview = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // タイムライン
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

                // カメラプレビュー
                CameraPreviewPlaceholder(
                    segmentDescription: viewModel.currentSegment?.segmentDescription,
                    guideImage: viewModel.guideImage,
                    showGuideImage: viewModel.showGuideImage,
                    isLoadingGuideImage: viewModel.isLoadingGuideImage
                )
                .aspectRatio(16/9, contentMode: .fit)

                // ストック動画エリア
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

                // コントロールエリア
                controlSection
            }
            .navigationTitle(viewModel.project.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }

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
        }
    }

    // MARK: - Sections

    private var controlSection: some View {
        VStack(spacing: 16) {
            // ガイド表示トグル
            HStack {
                Button {
                    viewModel.toggleGuideImage()
                } label: {
                    HStack {
                        Image(systemName: viewModel.showGuideImage ? "eye.fill" : "eye.slash.fill")
                        Text("ガイド")
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.bordered)

                Spacer()

                // 撮影時間表示
                if viewModel.isRecording {
                    Text(formatTime(viewModel.recordingDuration))
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundColor(.red)
                }
            }

            // 撮影ボタン
            RecordButtonWithProgress(
                isRecording: viewModel.isRecording,
                progress: recordingProgress,
                canRecord: canRecord,
                onTap: {
                    if viewModel.isRecording {
                        viewModel.stopRecording()
                    } else {
                        viewModel.startRecording()
                    }
                }
            )
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Helpers

    private var canRecord: Bool {
        guard let currentSegment = viewModel.currentSegment else { return false }
        return viewModel.canRecord(for: currentSegment.order)
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
        deleteVideoAssetUseCase: DeleteVideoAssetUseCase(repository: container.projectRepository)
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
            deleteVideoAssetUseCase: DeleteVideoAssetUseCase(repository: container.projectRepository)
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
        deleteVideoAssetUseCase: DeleteVideoAssetUseCase(repository: container.projectRepository)
    )
    RecordingView(viewModel: viewModel)
}
