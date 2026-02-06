import Foundation

@MainActor
final class AnalyzeVideoUseCase {

    // MARK: - Properties

    private let repository: GeminiRepositoryProtocol

    // MARK: - Init

    init(repository: GeminiRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute(videoURL: URL) async throws -> VideoAnalysisResult {
        try await repository.analyzeVideo(url: videoURL)
    }
}
