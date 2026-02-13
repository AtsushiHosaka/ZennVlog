import Foundation

protocol GeminiRepositoryProtocol: Sendable {
    func sendMessage(_ message: String, history: [ChatMessageDTO]) async throws -> GeminiChatResponse
    func analyzeVideo(url: URL) async throws -> VideoAnalysisResult
    func sendTurn(
        systemInstruction: String,
        contents: [[String: Any]],
        tools: [[String: Any]]
    ) async throws -> GeminiTurnResponse
}
