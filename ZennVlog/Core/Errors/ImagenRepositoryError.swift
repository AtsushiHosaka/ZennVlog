import Foundation

enum ImagenRepositoryError: LocalizedError, RepositoryErrorWrappable {
    case invalidAPIKey
    case requestFailed(underlying: Error)
    case generationFailed(underlying: Error)
    case invalidImageData
    case rateLimited
    case unknown(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "APIキーが無効です"
        case .requestFailed(let error):
            return "リクエストに失敗しました: \(error.localizedDescription)"
        case .generationFailed(let error):
            return "画像生成に失敗しました: \(error.localizedDescription)"
        case .invalidImageData:
            return "画像データが無効です"
        case .rateLimited:
            return "リクエスト制限に達しました。しばらくお待ちください"
        case .unknown(let error):
            return "予期しないエラーが発生しました: \(error.localizedDescription)"
        }
    }
}
