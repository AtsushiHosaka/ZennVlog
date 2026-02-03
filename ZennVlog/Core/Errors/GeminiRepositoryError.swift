import Foundation

enum GeminiRepositoryError: LocalizedError, RepositoryErrorWrappable {
    case invalidAPIKey
    case requestFailed(underlying: Error)
    case responseParseFailed(underlying: Error)
    case rateLimited
    case videoAnalysisFailed(underlying: Error)
    case unsupportedVideoFormat
    case unknown(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "APIキーが無効です"
        case .requestFailed(let error):
            return "リクエストに失敗しました: \(error.localizedDescription)"
        case .responseParseFailed(let error):
            return "レスポンスの解析に失敗しました: \(error.localizedDescription)"
        case .rateLimited:
            return "リクエスト制限に達しました。しばらくお待ちください"
        case .videoAnalysisFailed(let error):
            return "動画の解析に失敗しました: \(error.localizedDescription)"
        case .unsupportedVideoFormat:
            return "サポートされていない動画形式です"
        case .unknown(let error):
            return "予期しないエラーが発生しました: \(error.localizedDescription)"
        }
    }
}
