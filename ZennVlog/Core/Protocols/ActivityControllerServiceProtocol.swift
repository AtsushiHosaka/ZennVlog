import Foundation

/// SNS共有機能を抽象化するプロトコル
protocol ActivityControllerServiceProtocol: Sendable {
    /// アイテムを共有シートに表示して共有
    /// - Parameter items: 共有するアイテム（URL、画像など）
    /// - Returns: 共有が完了した場合true、キャンセルされた場合false
    func share(items: [Any]) async -> Bool
}
