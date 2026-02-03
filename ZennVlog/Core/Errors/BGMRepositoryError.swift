import Foundation

enum BGMRepositoryError: LocalizedError, RepositoryErrorWrappable {
    case notFound(String)
    case fetchFailed(underlying: Error)
    case downloadFailed(underlying: Error)
    case invalidURL(String)
    case unknown(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return "BGMが見つかりません: \(id)"
        case .fetchFailed(let error):
            return "BGMの取得に失敗しました: \(error.localizedDescription)"
        case .downloadFailed(let error):
            return "BGMのダウンロードに失敗しました: \(error.localizedDescription)"
        case .invalidURL(let url):
            return "無効なURL: \(url)"
        case .unknown(let error):
            return "予期しないエラーが発生しました: \(error.localizedDescription)"
        }
    }
}
