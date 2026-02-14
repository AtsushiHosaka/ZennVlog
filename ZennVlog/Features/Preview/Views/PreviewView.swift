import SwiftUI

/// 動画プレビュー・編集画面
struct PreviewView: View {
    @State var viewModel: PreviewViewModel
    let container: DIContainer

    @Environment(\.dismiss) private var dismiss
    @State private var showShareView = false
    @State private var exportedURL: URL?
    @State private var isPreviewScrubbing = false
    @State private var previewScrubStartTime: Double = 0
    @State private var controlsPanelHeight: CGFloat = 0
    @State private var isDraggingSubtitle = false
    @State private var presentedSubtitleSheet: SubtitleSheetState?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                previewBackground

                controlsPanel
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("プレビュー")
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
                    Button {
                        Task {
                            await handleExport()
                        }
                    } label: {
                        if viewModel.isExporting {
                            ProgressView()
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    .disabled(viewModel.isExporting)
                }
            }
            .sheet(item: $presentedSubtitleSheet) { state in
                SubtitleEditSheet(
                    initialState: state,
                    maxDuration: max(viewModel.duration, 0),
                    onSave: { draft in
                        let success = await viewModel.saveSubtitle(draft)
                        if success {
                            presentedSubtitleSheet = nil
                        }
                        return success
                    },
                    onDelete: { subtitleId in
                        let success = await viewModel.deleteSubtitle(subtitleId: subtitleId)
                        if success {
                            presentedSubtitleSheet = nil
                        }
                        return success
                    },
                    onDismiss: {
                        presentedSubtitleSheet = nil
                        viewModel.dismissSubtitleSheet()
                    }
                )
            }
            .sheet(isPresented: $viewModel.showBGMSettingsSheet) {
                BGMSettingsSheet(
                    bgmTracks: viewModel.bgmTracks,
                    initialSelectedBGM: viewModel.selectedBGM,
                    initialVolume: viewModel.bgmVolume,
                    onSave: { track, volume in
                        await viewModel.saveBGMSettings(track: track, volume: volume)
                    },
                    onDismiss: {
                        viewModel.showBGMSettingsSheet = false
                    }
                )
            }
            .fullScreenCover(isPresented: $showShareView) {
                if let exportedURL {
                    ShareView(
                        viewModel: ShareViewModel(
                            project: viewModel.project,
                            exportedVideoURL: exportedURL,
                            photoLibrary: container.photoLibraryService,
                            activityController: container.activityControllerService
                        )
                    )
                } else {
                    Text("共有する動画が見つかりません")
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
        }
        .task {
            await viewModel.loadProject()
        }
    }

    // MARK: - Layout

    private var previewBackground: some View {
        GeometryReader { proxy in
            let activeSubtitle = viewModel.activeSubtitle(at: viewModel.currentTime)

            ZStack {
                VideoPlayerView(player: viewModel.player)
                    .aspectRatio(16 / 9, contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .background(Color.black)
                    .contentShape(Rectangle())
                    .gesture(previewScrubGesture)

                SubtitleOverlay(
                    subtitle: activeSubtitle,
                    bottomBlockedInset: controlsPanelHeight + 6,
                    onDragStart: {
                        isDraggingSubtitle = true
                        if isPreviewScrubbing {
                            isPreviewScrubbing = false
                            viewModel.endTimelineScrub()
                        }
                    },
                    onDragEnd: {
                        isDraggingSubtitle = false
                    },
                    onPositionCommit: { subtitleId, xRatio, yRatio in
                        viewModel.updateSubtitlePosition(
                            subtitleId: subtitleId,
                            positionXRatio: xRatio,
                            positionYRatio: yRatio
                        )
                    }
                )
                .id(activeSubtitle?.id)
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    private var controlsPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    viewModel.togglePlayPause()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(.white)
                }

                Text(formatTime(viewModel.currentTime))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundColor(.white)

                Text("/")
                    .foregroundColor(.white.opacity(0.7))

                Text(formatTime(viewModel.duration))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                Button {
                    viewModel.showBGMSettingsSheet = true
                } label: {
                    Image(systemName: "music.note")
                        .font(.footnote.weight(.semibold))
                        .padding(8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.18))
            }

            LinkedTimelineTracksView(
                duration: viewModel.duration,
                currentTime: viewModel.currentTime,
                videoSegments: viewModel.timelineSegments,
                subtitles: viewModel.subtitles,
                onSeek: { time in
                    viewModel.seek(to: time)
                },
                onBeginScrub: {
                    viewModel.beginTimelineScrub()
                },
                onEndScrub: {
                    viewModel.endTimelineScrub()
                },
                onSubtitleTap: { subtitle in
                    viewModel.showEditSubtitleSheet(subtitle)
                    presentedSubtitleSheet = viewModel.subtitleSheetState
                },
                onAddSubtitle: {
                    viewModel.showNewSubtitleSheet(at: viewModel.currentTime)
                    presentedSubtitleSheet = viewModel.subtitleSheetState
                }
            )
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
        .readHeight { controlsPanelHeight = $0 }
    }

    // MARK: - Helpers

    private func handleExport() async {
        guard let url = await viewModel.exportVideo() else { return }
        exportedURL = url
        showShareView = true
    }

    private var previewScrubGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !isDraggingSubtitle else { return }
                if !isPreviewScrubbing {
                    isPreviewScrubbing = true
                    previewScrubStartTime = viewModel.currentTime
                    viewModel.beginTimelineScrub()
                }

                let pointsPerSecond: CGFloat = 70
                let deltaSeconds = Double(-value.translation.width / pointsPerSecond)
                viewModel.seek(to: max(0, previewScrubStartTime + deltaSeconds))
            }
            .onEnded { _ in
                guard !isDraggingSubtitle else { return }
                guard isPreviewScrubbing else { return }
                isPreviewScrubbing = false
                viewModel.endTimelineScrub()
            }
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = Int(max(0, seconds).rounded(.down))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

private struct ControlsPanelHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private extension View {
    func readHeight(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: ControlsPanelHeightPreferenceKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(ControlsPanelHeightPreferenceKey.self, perform: onChange)
    }
}

// MARK: - Previews

#Preview("通常") {
    let container = DIContainer.preview
    let project = Project(
        name: "週末のお出かけVlog",
        theme: "日常",
        template: Template(
            segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 10, segmentDescription: "オープニング"),
                Segment(order: 1, startSeconds: 10, endSeconds: 25, segmentDescription: "朝の様子"),
                Segment(order: 2, startSeconds: 25, endSeconds: 40, segmentDescription: "昼の活動")
            ]
        ),
        subtitles: [
            Subtitle(startSeconds: 0, endSeconds: 3.5, text: "朝の散歩スタート"),
            Subtitle(startSeconds: 12, endSeconds: 16, text: "カフェに到着")
        ]
    )
    let viewModel = PreviewViewModel(
        project: project,
        exportVideoUseCase: ExportVideoUseCase(repository: container.projectRepository),
        fetchBGMTracksUseCase: FetchBGMTracksUseCase(repository: container.bgmRepository),
        saveSubtitleUseCase: SaveSubtitleUseCase(repository: container.projectRepository),
        deleteSubtitleUseCase: DeleteSubtitleUseCase(repository: container.projectRepository),
        saveBGMSettingsUseCase: SaveBGMSettingsUseCase(repository: container.projectRepository),
        downloadBGMUseCase: DownloadBGMUseCase(repository: container.bgmRepository),
        updateSubtitlePositionUseCase: UpdateSubtitlePositionUseCase(repository: container.projectRepository)
    )
    PreviewView(viewModel: viewModel, container: container)
}

#Preview("書き出し中") {
    ExportingPreviewWrapper()
}

private struct ExportingPreviewWrapper: View {
    @State private var viewModel: PreviewViewModel
    private let container: DIContainer

    init() {
        let container = DIContainer.preview
        self.container = container
        let project = Project(name: "テストプロジェクト")
        let vm = PreviewViewModel(
            project: project,
            exportVideoUseCase: ExportVideoUseCase(repository: container.projectRepository),
            fetchBGMTracksUseCase: FetchBGMTracksUseCase(repository: container.bgmRepository),
            saveSubtitleUseCase: SaveSubtitleUseCase(repository: container.projectRepository),
            deleteSubtitleUseCase: DeleteSubtitleUseCase(repository: container.projectRepository),
            saveBGMSettingsUseCase: SaveBGMSettingsUseCase(repository: container.projectRepository),
            downloadBGMUseCase: DownloadBGMUseCase(repository: container.bgmRepository),
            updateSubtitlePositionUseCase: UpdateSubtitlePositionUseCase(repository: container.projectRepository)
        )
        vm.isExporting = true
        vm.exportProgress = 0.45
        _viewModel = State(wrappedValue: vm)
    }

    var body: some View {
        PreviewView(viewModel: viewModel, container: container)
    }
}
