import AVFoundation
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

    func exportVideoToTemporaryFile(assetIdentifier: String) async throws -> URL {
        let granted = await requestReadAuthorizationIfNeeded()
        guard granted else { throw PhotoLibraryServiceError.permissionDenied }

        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = fetch.firstObject else {
            throw PhotoLibraryServiceError.assetNotFound
        }

        let avAsset = try await requestAVAsset(for: asset)
        return try await exportToTemporaryFile(avAsset)
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
        
        guard let id = placeholderId else {
            throw PhotoLibraryServiceError.assetCreationFailed
        }
        return id
    }

    private func requestReadAuthorizationIfNeeded() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                    continuation.resume(returning: newStatus == .authorized || newStatus == .limited)
                }
            }
        default:
            return false
        }
    }

    private func requestAVAsset(for asset: PHAsset) async throws -> AVAsset {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.version = .original

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    continuation.resume(throwing: PhotoLibraryServiceError.assetExportFailed)
                    return
                }

                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let avAsset else {
                    continuation.resume(throwing: PhotoLibraryServiceError.assetNotFound)
                    return
                }

                continuation.resume(returning: avAsset)
            }
        }
    }

    private func exportToTemporaryFile(_ asset: AVAsset) async throws -> URL {
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw PhotoLibraryServiceError.assetExportFailed
        }

        let fileType: AVFileType
        if session.supportedFileTypes.contains(.mp4) {
            fileType = .mp4
        } else if session.supportedFileTypes.contains(.mov) {
            fileType = .mov
        } else if let fallback = session.supportedFileTypes.first {
            fileType = fallback
        } else {
            throw PhotoLibraryServiceError.assetExportFailed
        }

        let fileExtension: String
        switch fileType {
        case .mp4:
            fileExtension = "mp4"
        default:
            fileExtension = "mov"
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
            .standardizedFileURL

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        try await session.export(to: outputURL, as: fileType)
        return outputURL
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
    case assetNotFound
    case assetExportFailed
}
