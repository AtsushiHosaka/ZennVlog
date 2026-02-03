import Foundation

protocol GeminiRepositoryProtocol: Sendable {
    func sendMessage(_ message: String, history: [ChatMessage]) async throws -> GeminiChatResponse
    func analyzeVideo(url: URL) async throws -> VideoAnalysisResult
}
