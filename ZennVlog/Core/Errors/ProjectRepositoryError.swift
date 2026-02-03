import Foundation

enum ProjectRepositoryError: LocalizedError, RepositoryErrorWrappable {
    case notFound(UUID)
    case saveFailed(underlying: Error)
    case deleteFailed(underlying: Error)
    case fetchFailed(underlying: Error)
    case unknown(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return "プロジェクトが見つかりません: \(id)"
        case .saveFailed(let error):
            return "プロジェクトの保存に失敗しました: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "プロジェクトの削除に失敗しました: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "プロジェクトの取得に失敗しました: \(error.localizedDescription)"
        case .unknown(let error):
            return "予期しないエラーが発生しました: \(error.localizedDescription)"
        }
    }
}
