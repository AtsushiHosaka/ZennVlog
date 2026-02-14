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
    
    func saveVideoToAlbum(videoURL: URL, projectName: String) async throws -> String {
        print("PHOTO status(addOnly):", PHPhotoLibrary.authorizationStatus(for: .addOnly).rawValue)
        print("PHOTO status(readWrite):", PHPhotoLibrary.authorizationStatus(for: .readWrite).rawValue)
        print("FILE exists:", FileManager.default.fileExists(atPath: videoURL.path), videoURL)

        // 1) 権限（Add-only）
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let granted: Bool
        
        switch status {
        case .authorized, .limited:
            granted = true
        case .notDetermined:
            granted = await withCheckedContinuation { cont in
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                    cont.resume(returning: newStatus == .authorized || newStatus == .limited)
                }
            }
        default:
            granted = false
        }
        
        guard granted else { throw PhotoLibraryServiceError.permissionDenied }
        
        // 2) アルバム取得 or 作成
        let album = try await fetchOrCreateAlbum(title: projectName)
        
        // 3) 追加して localIdentifier を返す
        return try await addVideo(videoURL: videoURL, to: album)
    }
    
    private func fetchOrCreateAlbum(title: String) async throws -> PHAssetCollection {
        if let existing = fetchAlbum(title: title) {
            return existing
        }
        
        // 作成
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
        }
        
        guard let created = fetchAlbum(title: title) else {
            throw PhotoLibraryServiceError.albumCreationFailed
        }
        return created
    }
    
    private func fetchAlbum(title: String) -> PHAssetCollection? {
        let fetch = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var result: PHAssetCollection?
        fetch.enumerateObjects { collection, _, stop in
            if collection.localizedTitle == title {
                result = collection
                stop.pointee = true
            }
        }
        return result
    }
    
    private func addVideo(videoURL: URL, to album: PHAssetCollection) async throws -> String {
        var placeholderId: String?
        
        try await PHPhotoLibrary.shared().performChanges {
            let createReq = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            placeholderId = createReq?.placeholderForCreatedAsset?.localIdentifier
            
            if let placeholder = createReq?.placeholderForCreatedAsset,
               let albumReq = PHAssetCollectionChangeRequest(for: album) {
                albumReq.addAssets([placeholder] as NSArray)
            }
        }
        
        print("placeholderId:", placeholderId ?? "nil")
        
        guard let id = placeholderId else {
            throw PhotoLibraryServiceError.assetCreationFailed
        }
        return id
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

enum PhotoLibraryServiceError: Error {
    case permissionDenied
    case albumCreationFailed
    case assetCreationFailed
}
