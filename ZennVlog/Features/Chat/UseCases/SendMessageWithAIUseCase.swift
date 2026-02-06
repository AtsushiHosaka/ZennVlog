import Foundation

@MainActor
final class SendMessageWithAIUseCase {

    // MARK: - Properties

    private let repository: GeminiRepositoryProtocol

    // MARK: - Init

    init(repository: GeminiRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute(message: String, history: [ChatMessageDTO]) async throws -> GeminiChatResponse {
        try await repository.sendMessage(message, history: history)
    }
}
