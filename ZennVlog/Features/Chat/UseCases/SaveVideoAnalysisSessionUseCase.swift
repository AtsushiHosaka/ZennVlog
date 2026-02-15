import Foundation

enum SaveVideoAnalysisSessionError: LocalizedError {
    case projectNotFound

    var errorDescription: String? {
        switch self {
        case .projectNotFound:
            return "解析結果の保存先プロジェクトが見つかりませんでした"
        }
    }
}

@MainActor
final class SaveVideoAnalysisSessionUseCase {

    // MARK: - Properties

    private let repository: ProjectRepositoryProtocol

    // MARK: - Init

    init(repository: ProjectRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Execute

    @discardableResult
    func execute(
        projectId: UUID,
        sourceVideoURL: URL,
        result: VideoAnalysisResult
    ) async throws -> VideoAnalysisSession {
        guard let project = try await repository.fetch(by: projectId) else {
            throw SaveVideoAnalysisSessionError.projectNotFound
        }

        let scenes = result.segments.map { segment in
            VideoAnalysisScene(
                startSeconds: segment.startSeconds,
                endSeconds: segment.endSeconds,
                sceneDescription: segment.description,
                confidence: segment.confidence,
                visualLabels: segment.visualLabels ?? []
            )
        }

        let session = VideoAnalysisSession(
            sourceVideoURL: sourceVideoURL.absoluteString,
            scenes: scenes
        )
        project.videoAnalysisSessions.append(session)
        project.updatedAt = Date()

        try await repository.save(project)
        return session
    }
}
