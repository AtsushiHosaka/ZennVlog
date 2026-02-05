import SwiftUI
import Photos

/// Share機能のシステム統合レイヤー
/// Note: ViewModelでもUseCaseでもなく、テスト可能なシステム統合ラッパー
@MainActor
final class ShareSystem: ObservableObject {
    // MARK: - Published Properties

    @Published var isSaving: Bool = false
    @Published var saveSuccess: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let photoLibrary: PhotoLibraryServiceProtocol
    private let activityController: ActivityControllerServiceProtocol

    // MARK: - Initialization

    init(
        photoLibrary: PhotoLibraryServiceProtocol,
        activityController: ActivityControllerServiceProtocol
    ) {
        self.photoLibrary = photoLibrary
        self.activityController = activityController
    }

    // MARK: - Public Methods

    /// 動画を写真ライブラリに保存
    /// - Parameter videoURL: 保存する動画のURL
    /// - Throws: 権限エラーまたは保存エラー
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

            guard status == .authorized else {
                let message = createAuthorizationErrorMessage(for: status)
                errorMessage = message
                throw ShareSystemError.authorizationDenied(message)
            }

            // 動画を保存
            try await photoLibrary.saveVideo(at: videoURL)

            // 成功状態を更新
            saveSuccess = true

        } catch let error as ShareSystemError {
            // 既に設定されたエラーメッセージを保持
            throw error
        } catch {
            // その他のエラー
            errorMessage = "動画の保存に失敗しました: \(error.localizedDescription)"
            throw error
        }
    }

    /// SNSに動画を共有
    /// - Parameters:
    ///   - videoURL: 共有する動画のURL
    ///   - thumbnail: オプションのサムネイル画像
    /// - Returns: 共有が完了した場合true、キャンセルされた場合false
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

    /// 権限ステータスに応じたエラーメッセージを生成
    /// - Parameter status: 権限ステータス
    /// - Returns: エラーメッセージ
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

enum ShareSystemError: Error, LocalizedError {
    case authorizationDenied(String)

    var errorDescription: String? {
        switch self {
        case .authorizationDenied(let message):
            return message
        }
    }
}
