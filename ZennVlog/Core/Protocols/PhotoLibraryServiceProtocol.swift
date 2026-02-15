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

    /// 写真ライブラリ上の動画を一時ファイルとして書き出す
    /// - Parameter assetIdentifier: PHAssetのlocalIdentifier
    /// - Returns: 一時ファイルURL
    /// - Throws: 取得または書き出しに失敗した場合のエラー
    func exportVideoToTemporaryFile(assetIdentifier: String) async throws -> URL
}
