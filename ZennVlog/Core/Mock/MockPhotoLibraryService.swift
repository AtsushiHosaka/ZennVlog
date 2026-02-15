import Foundation
import Photos

/// 写真ライブラリサービスのモック実装
@MainActor
final class MockPhotoLibraryService: PhotoLibraryServiceProtocol {
    
    // MARK: - Mock Configuration

    /// エラーを発生させるかどうか
    var shouldThrowError: Bool = false

    /// モックで返す権限ステータス
    var mockAuthorizationStatus: PHAuthorizationStatus = .authorized

    // MARK: - Tracking Properties

    /// saveVideo呼び出し回数
    private(set) var saveCallCount: Int = 0

    /// 最後に保存されたURL
    private(set) var lastSavedURL: URL?
    
    /// 既存の動画
    private(set) var savedVideos: [(url: URL, projectName: String)] = []

    /// 疑似復旧元ファイル（assetIdentifier -> URL）
    var mockExportSourcesByAssetIdentifier: [String: URL] = [:]

    // MARK: - PhotoLibraryServiceProtocol

    func requestAuthorization() async -> PHAuthorizationStatus {
        // ネットワーク遅延をシミュレーション
        try? await simulateNetworkDelay()
        return mockAuthorizationStatus
    }
    
    func saveVideoToAlbum(videoURL: URL, projectName: String) async throws -> String {
        // 疑似的に保存履歴を残す
        savedVideos.append((url: videoURL, projectName: projectName))
        
        // 本番のように疑似 assetId を返す
        return "mock-asset-\(UUID().uuidString)"
    }

    func saveVideo(at url: URL) async throws {
        saveCallCount += 1
        lastSavedURL = url

        // ネットワーク遅延をシミュレーション
        try await simulateNetworkDelay()

        if shouldThrowError {
            throw MockPhotoLibraryError.saveFailed
        }
    }

    func exportVideoToTemporaryFile(assetIdentifier: String) async throws -> URL {
        try await simulateNetworkDelay()

        if shouldThrowError {
            throw MockPhotoLibraryError.saveFailed
        }

        guard let sourceURL = mockExportSourcesByAssetIdentifier[assetIdentifier],
              FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw MockPhotoLibraryError.assetNotFound
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension)

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination.standardizedFileURL
    }

    // MARK: - Helper Methods

    /// テスト用の状態リセット
    func reset() {
        shouldThrowError = false
        mockAuthorizationStatus = .authorized
        saveCallCount = 0
        lastSavedURL = nil
        mockExportSourcesByAssetIdentifier = [:]
    }

    /// ネットワーク遅延をシミュレーション (300ms)
    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
    }
}

// MARK: - Mock Errors

enum MockPhotoLibraryError: Error {
    case saveFailed
    case unauthorized
    case assetNotFound
}
