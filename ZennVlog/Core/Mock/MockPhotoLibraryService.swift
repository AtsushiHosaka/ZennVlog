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

    // MARK: - PhotoLibraryServiceProtocol

    func requestAuthorization() async -> PHAuthorizationStatus {
        // ネットワーク遅延をシミュレーション
        try? await simulateNetworkDelay()
        return mockAuthorizationStatus
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

    // MARK: - Helper Methods

    /// テスト用の状態リセット
    func reset() {
        shouldThrowError = false
        mockAuthorizationStatus = .authorized
        saveCallCount = 0
        lastSavedURL = nil
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
}
