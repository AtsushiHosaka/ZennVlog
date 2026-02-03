import Foundation

protocol GeminiRepositoryProtocol: Sendable {
    func sendMessage(_ message: String, history: [ChatMessageDTO]) async throws -> GeminiChatResponse
    func analyzeVideo(url: URL) async throws -> VideoAnalysisResult
}
