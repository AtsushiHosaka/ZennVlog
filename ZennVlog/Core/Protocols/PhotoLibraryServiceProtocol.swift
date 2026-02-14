import Photos

/// 写真ライブラリへのアクセスを抽象化するプロトコル
protocol PhotoLibraryServiceProtocol: Sendable {
    /// 写真ライブラリへのアクセス権限をリクエスト
    /// - Returns: 権限ステータス
    func requestAuthorization() async -> PHAuthorizationStatus

    /// 動画を写真ライブラリに保存
    /// - Parameter url: 保存する動画ファイルのURL
    /// - Throws: 保存に失敗した場合のエラー
    func saveVideo(at url: URL) async throws
    func saveVideoToAlbum(videoURL: URL, projectName: String) async throws -> String
}
