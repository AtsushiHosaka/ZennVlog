import Photos

/// 写真ライブラリサービスの本番実装
final class RealPhotoLibraryService: PhotoLibraryServiceProtocol {

    func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    func saveVideo(at url: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: PhotoLibraryError.saveFailed)
                }
            }
        }
    }
}

// MARK: - Errors

enum PhotoLibraryError: Error, LocalizedError {
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "動画の保存に失敗しました"
        }
    }
}
