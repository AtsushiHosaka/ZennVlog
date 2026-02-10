import SwiftUI

/// 完成したVlogをSNSに共有する画面
struct ShareView: View {
    @State var viewModel: ShareViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                // メインコンテンツ
                ScrollView {
                    VStack(spacing: 24) {
                        // 動画サムネイル
                        thumbnailSection

                        // プロジェクト情報
                        projectInfoSection

                        // SNS共有ボタン群
                        snsButtonsSection

                        // 端末に保存ボタン
                        saveToDeviceSection

                        Spacer(minLength: 40)
                    }
                    .padding()
                }

                // 保存成功オーバーレイ
                if viewModel.saveSuccess {
                    successOverlay
                }
            }
            .navigationTitle("共有")
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
            .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
                if viewModel.errorMessage?.contains("許可されていません") == true {
                    Button("設定を開く") {
                        openSettings()
                    }
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    // MARK: - Sections

    /// サムネイル表示セクション
    private var thumbnailSection: some View {
        Group {
            if let thumbnail = viewModel.thumbnailImage {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(9/16, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .cornerRadius(16)
                    .shadow(radius: 8)
            } else {
                // プレースホルダー
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(9/16, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("動画プレビュー")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
            }
        }
    }

    /// プロジェクト情報セクション
    private var projectInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.project.name)
                .font(.title2)
                .fontWeight(.bold)

            if !viewModel.project.theme.isEmpty {
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundColor(.secondary)
                    Text(viewModel.project.theme)
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// SNS共有ボタン群セクション
    private var snsButtonsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SNSに共有")
                .font(.headline)

            HStack(spacing: 24) {
                ForEach(SNSType.allCases, id: \.self) { type in
                    SNSButton(type: type) {
                        Task {
                            _ = try? await viewModel.shareToSNS()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// 端末に保存セクション
    private var saveToDeviceSection: some View {
        VStack(spacing: 16) {
            Button {
                Task {
                    try? await viewModel.saveToPhotoLibrary()
                }
            } label: {
                HStack {
                    if viewModel.isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    } else {
                        Image(systemName: "square.and.arrow.down.fill")
                    }
                    Text(viewModel.isSaving ? "保存中..." : "端末に保存")
                }
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(viewModel.isSaving ? Color.gray : Color.accentColor)
                .cornerRadius(12)
            }
            .disabled(viewModel.isSaving)
        }
    }

    /// 保存成功オーバーレイ
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)

                Text("カメラロールに保存しました")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(Color(UIColor.systemBackground).opacity(0.95))
            .cornerRadius(16)
            .shadow(radius: 16)
        }
        .onTapGesture {
            viewModel.saveSuccess = false
        }
        .onAppear {
            // 3秒後に自動で非表示
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                viewModel.saveSuccess = false
            }
        }
    }

    // MARK: - Helper Methods

    /// 設定アプリを開く
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview Helpers

/// Preview用のモックProject作成
private func createMockProject() -> Project {
    Project(
        id: UUID(),
        name: "週末のお出かけVlog",
        theme: "旅行",
        projectDescription: "週末に行った温泉旅行の思い出"
    )
}

/// Preview用のモックURL作成
private func createMockVideoURL() -> URL {
    URL(string: "mock://video/exported.mp4")!
}

// MARK: - Previews

#Preview("通常状態") {
    let container = DIContainer.preview
    let viewModel = ShareViewModel(
        project: createMockProject(),
        exportedVideoURL: createMockVideoURL(),
        thumbnailImage: nil,
        photoLibrary: container.photoLibraryService,
        activityController: container.activityControllerService
    )
    return ShareView(viewModel: viewModel)
}

#Preview("保存成功") {
    let container = DIContainer.preview
    let viewModel = ShareViewModel(
        project: createMockProject(),
        exportedVideoURL: createMockVideoURL(),
        thumbnailImage: nil,
        photoLibrary: container.photoLibraryService,
        activityController: container.activityControllerService
    )
    viewModel.saveSuccess = true
    return ShareView(viewModel: viewModel)
}

#Preview("保存中") {
    let container = DIContainer.preview
    let viewModel = ShareViewModel(
        project: createMockProject(),
        exportedVideoURL: createMockVideoURL(),
        thumbnailImage: nil,
        photoLibrary: container.photoLibraryService,
        activityController: container.activityControllerService
    )
    viewModel.isSaving = true
    return ShareView(viewModel: viewModel)
}

#Preview("エラー状態") {
    let container = DIContainer.preview
    let viewModel = ShareViewModel(
        project: createMockProject(),
        exportedVideoURL: createMockVideoURL(),
        thumbnailImage: nil,
        photoLibrary: container.photoLibraryService,
        activityController: container.activityControllerService
    )
    viewModel.errorMessage = "写真ライブラリへのアクセスが許可されていません。設定アプリから権限を許可してください。"
    return ShareView(viewModel: viewModel)
}
