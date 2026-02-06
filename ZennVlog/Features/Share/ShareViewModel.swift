import Observation
import Photos
import SwiftUI

@MainActor
@Observable
final class ShareViewModel {
    // MARK: - Data Properties

    let project: Project
    let exportedVideoURL: URL
    var thumbnailImage: UIImage?

    // MARK: - State Properties

    var isSaving: Bool = false
    var saveSuccess: Bool = false
    var errorMessage: String?

    // MARK: - Dependencies

    private let photoLibrary: PhotoLibraryServiceProtocol
    private let activityController: ActivityControllerServiceProtocol

    // MARK: - Initialization

    init(
        project: Project,
        exportedVideoURL: URL,
        thumbnailImage: UIImage? = nil,
        photoLibrary: PhotoLibraryServiceProtocol,
        activityController: ActivityControllerServiceProtocol
    ) {
        self.project = project
        self.exportedVideoURL = exportedVideoURL
        self.thumbnailImage = thumbnailImage
        self.photoLibrary = photoLibrary
        self.activityController = activityController
    }

    // MARK: - Public Methods

    func saveToPhotoLibrary() async throws {
        try await saveToPhotoLibrary(videoURL: exportedVideoURL)
    }

    func saveToPhotoLibrary(videoURL: URL) async throws {
        // 状態をリセット
        isSaving = true
        saveSuccess = false
        errorMessage = nil

        defer {
            isSaving = false
        }

        do {
            // 権限チェック
            let status = await photoLibrary.requestAuthorization()

            // iOS 14以降は .limited も許可（ユーザーが選択した写真へのアクセスは制限されるが、書き込みは可能）
            guard status == .authorized || status == .limited else {
                let message = createAuthorizationErrorMessage(for: status)
                errorMessage = message
                throw ShareViewModelError.authorizationDenied(message)
            }

            // 動画を保存
            try await photoLibrary.saveVideo(at: videoURL)

            // 成功状態を更新
            saveSuccess = true

        } catch let error as ShareViewModelError {
            // 既に設定されたエラーメッセージを保持
            throw error
        } catch {
            // その他のエラー
            errorMessage = "動画の保存に失敗しました: \(error.localizedDescription)"
            throw error
        }
    }

    func shareToSNS() async throws -> Bool {
        try await shareToSNS(videoURL: exportedVideoURL, thumbnail: thumbnailImage)
    }

    func shareToSNS(videoURL: URL, thumbnail: UIImage? = nil) async throws -> Bool {
        var items: [Any] = [videoURL]

        // サムネイルが存在する場合は追加
        if let thumbnail = thumbnail {
            items.append(thumbnail)
        }

        // アクティビティコントローラーで共有
        let result = await activityController.share(items: items)

        return result
    }

    // MARK: - Private Methods

    private func createAuthorizationErrorMessage(for status: PHAuthorizationStatus) -> String {
        switch status {
        case .denied, .restricted:
            return "写真ライブラリへのアクセスが許可されていません。設定アプリから権限を許可してください。"
        case .notDetermined:
            return "写真ライブラリへのアクセス権限を確認してください。"
        case .authorized, .limited:
            return "" // 通常は到達しない
        @unknown default:
            return "写真ライブラリへのアクセス権限を確認してください。"
        }
    }
}

// MARK: - Errors

enum ShareViewModelError: Error, LocalizedError {
    case authorizationDenied(String)

    var errorDescription: String? {
        switch self {
        case .authorizationDenied(let message):
            return message
        }
    }
}
