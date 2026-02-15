import Foundation

enum SyncChatHistoryError: LocalizedError {
    case projectNotFound

    var errorDescription: String? {
        switch self {
        case .projectNotFound:
            return "チャット履歴の保存対象プロジェクトが見つかりません"
        }
    }
}

@MainActor
final class SyncChatHistoryUseCase {

    // MARK: - Properties

    private let repository: ProjectRepositoryProtocol

    // MARK: - Init

    init(repository: ProjectRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute(projectId: UUID, message: ChatMessage) async throws {
        guard let project = try await repository.fetch(by: projectId) else {
            throw SyncChatHistoryError.projectNotFound
        }

        project.chatHistory.append(message)
        project.updatedAt = Date()
        try await repository.save(project)
    }
}
