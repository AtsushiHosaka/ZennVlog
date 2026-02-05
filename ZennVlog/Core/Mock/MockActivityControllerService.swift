import Foundation

/// アクティビティコントローラーサービスのモック実装
@MainActor
final class MockActivityControllerService: ActivityControllerServiceProtocol {
    // MARK: - Mock Configuration

    /// 共有が成功するかどうか（false = キャンセル）
    var shouldSucceed: Bool = true

    // MARK: - Tracking Properties

    /// share呼び出し回数
    private(set) var shareCallCount: Int = 0

    /// 最後に共有されたアイテム
    private(set) var lastSharedItems: [Any] = []

    // MARK: - ActivityControllerServiceProtocol

    func share(items: [Any]) async -> Bool {
        shareCallCount += 1
        lastSharedItems = items

        // ネットワーク遅延をシミュレーション
        try? await simulateNetworkDelay()

        return shouldSucceed
    }

    // MARK: - Helper Methods

    /// テスト用の状態リセット
    func reset() {
        shouldSucceed = true
        shareCallCount = 0
        lastSharedItems = []
    }

    /// ネットワーク遅延をシミュレーション (300ms)
    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
    }
}
