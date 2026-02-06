import Foundation

@MainActor
final class InitializeChatSessionUseCase {

    // MARK: - Init

    init() {}

    // MARK: - Execute

    func execute(projectId: UUID, existingMessages: [ChatMessage]) async throws -> ChatSession {
        ChatSession(projectId: projectId, messages: existingMessages)
    }
}
