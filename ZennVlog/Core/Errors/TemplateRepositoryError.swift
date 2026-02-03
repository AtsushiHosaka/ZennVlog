import Foundation

enum TemplateRepositoryError: LocalizedError, RepositoryErrorWrappable {
    case notFound(String)
    case fetchFailed(underlying: Error)
    case decodeFailed(underlying: Error)
    case unknown(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return "テンプレートが見つかりません: \(id)"
        case .fetchFailed(let error):
            return "テンプレートの取得に失敗しました: \(error.localizedDescription)"
        case .decodeFailed(let error):
            return "テンプレートのデコードに失敗しました: \(error.localizedDescription)"
        case .unknown(let error):
            return "予期しないエラーが発生しました: \(error.localizedDescription)"
        }
    }
}
