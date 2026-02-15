import Foundation

@MainActor
final class ChatWorkflowManager {
    private let sendMessageUseCase: SendMessageWithAIUseCase
    private let saveVideoAnalysisSessionUseCase: SaveVideoAnalysisSessionUseCase

    init(
        sendMessageUseCase: SendMessageWithAIUseCase,
        saveVideoAnalysisSessionUseCase: SaveVideoAnalysisSessionUseCase
    ) {
        self.sendMessageUseCase = sendMessageUseCase
        self.saveVideoAnalysisSessionUseCase = saveVideoAnalysisSessionUseCase
    }

    func sendMessage(
        message: String,
        history: [ChatMessageDTO],
        attachedVideoURL: URL?,
        projectId: UUID?,
        chatMode: ChatMode,
        onToolExecution: ((ToolExecutionStatus) -> Void)? = nil
    ) async throws -> GeminiChatResponse {
        let response = try await sendMessageUseCase.execute(
            message: message,
            history: history,
            attachedVideoURL: attachedVideoURL,
            projectId: projectId,
            chatMode: chatMode,
            onToolExecution: onToolExecution
        )

        if let projectId,
           let attachedVideoURL,
           let analyzedVideoResult = response.analyzedVideoResult,
           !analyzedVideoResult.segments.isEmpty {
            try await saveVideoAnalysisSessionUseCase.execute(
                projectId: projectId,
                sourceVideoURL: attachedVideoURL,
                result: analyzedVideoResult
            )
        }

        return response
    }
}
