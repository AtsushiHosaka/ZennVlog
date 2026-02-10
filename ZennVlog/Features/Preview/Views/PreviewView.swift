import SwiftUI

/// 動画プレビュー・編集画面
/// テロップやBGMを追加して最終調整
struct PreviewView: View {
    @State var viewModel: PreviewViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 動画プレーヤー領域
                videoPlayerSection

                // タイムライン
                PreviewTimeline(
                    segments: viewModel.segments,
                    currentTime: viewModel.currentTime,
                    onSegmentTap: { index in
                        viewModel.seekToSegment(index)
                    }
                )

                // コントロールエリア
                controlSection

                // テロップ編集
                SubtitleEditor(
                    segmentIndex: viewModel.currentSegmentIndex,
                    subtitleText: $viewModel.subtitleText,
                    onSave: {
                        Task {
                            await viewModel.saveSubtitle()
                        }
                    }
                )
                .padding(.horizontal)

                // BGMコントロール
                bgmSection

                // 書き出しボタン
                exportSection
            }
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
            }
            .sheet(isPresented: $viewModel.showBGMSelector) {
                BGMSelector(
                    bgmTracks: viewModel.bgmTracks,
                    selectedBGM: viewModel.selectedBGM,
                    onSelect: { track in
                        Task {
                            await viewModel.selectBGM(track)
                        }
                    },
                    onDismiss: {
                        viewModel.showBGMSelector = false
                    }
                )
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

    // MARK: - Sections

    private var videoPlayerSection: some View {
        ZStack {
            // 動画プレーヤー
            VideoPlayerView(player: nil)
                .aspectRatio(16/9, contentMode: .fit)
                .background(Color.black)

            // テロップオーバーレイ
            SubtitleOverlay(text: viewModel.subtitleText)
        }
    }

    private var controlSection: some View {
        HStack(spacing: 20) {
            // 再生/一時停止ボタン
            Button {
                viewModel.togglePlayPause()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.accentColor)
            }

            // 時間表示
            Text(formatTime(viewModel.currentTime))
                .font(.caption)
                .monospacedDigit()

            // シークバー
            Slider(value: $viewModel.currentTime, in: 0...max(viewModel.duration, 1))
                .disabled(viewModel.duration == 0)

            Text(formatTime(viewModel.duration))
                .font(.caption)
                .monospacedDigit()
        }
        .padding()
    }

    private var bgmSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("BGM")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(viewModel.selectedBGM?.title ?? "未選択")
                    .foregroundColor(.secondary)

                Spacer()

                Button("変更") {
                    viewModel.showBGMSelector = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack {
                Image(systemName: "speaker.fill")
                    .foregroundColor(.secondary)

                Slider(value: $viewModel.bgmVolume, in: 0...1)

                Text("\(Int(viewModel.bgmVolume * 100))%")
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 40)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var exportSection: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    await viewModel.exportVideo()
                }
            } label: {
                HStack {
                    if viewModel.isExporting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    } else {
                        Image(systemName: "square.and.arrow.up.fill")
                    }
                    Text(viewModel.isExporting ? "書き出し中..." : "書き出して共有")
                }
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(viewModel.isExporting ? Color.gray : Color.accentColor)
                .cornerRadius(12)
            }
            .disabled(viewModel.isExporting)

            if viewModel.isExporting {
                ProgressView(value: viewModel.exportProgress)
                Text("\(Int(viewModel.exportProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
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
        )
    )
    let viewModel = PreviewViewModel(
        project: project,
        exportVideoUseCase: ExportVideoUseCase(repository: container.projectRepository),
        fetchBGMTracksUseCase: FetchBGMTracksUseCase(repository: container.bgmRepository),
        saveSubtitleUseCase: SaveSubtitleUseCase(repository: container.projectRepository),
        downloadBGMUseCase: DownloadBGMUseCase(repository: container.bgmRepository)
    )
    PreviewView(viewModel: viewModel)
}

#Preview("書き出し中") {
    ExportingPreviewWrapper()
}

private struct ExportingPreviewWrapper: View {
    @State private var viewModel: PreviewViewModel

    init() {
        let container = DIContainer.preview
        let project = Project(name: "テストプロジェクト")
        let vm = PreviewViewModel(
            project: project,
            exportVideoUseCase: ExportVideoUseCase(repository: container.projectRepository),
            fetchBGMTracksUseCase: FetchBGMTracksUseCase(repository: container.bgmRepository),
            saveSubtitleUseCase: SaveSubtitleUseCase(repository: container.projectRepository),
            downloadBGMUseCase: DownloadBGMUseCase(repository: container.bgmRepository)
        )
        vm.isExporting = true
        vm.exportProgress = 0.45
        _viewModel = State(wrappedValue: vm)
    }

    var body: some View {
        PreviewView(viewModel: viewModel)
    }
}
