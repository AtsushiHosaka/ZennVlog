import Foundation

enum UpdateSubtitlePositionError: LocalizedError, Equatable {
    case subtitleNotFound

    var errorDescription: String? {
        switch self {
        case .subtitleNotFound:
            return "対象のテロップが見つかりません"
        }
    }
}

@MainActor
final class UpdateSubtitlePositionUseCase {

    // MARK: - Properties

    private let repository: ProjectRepositoryProtocol

    // MARK: - Init

    init(repository: ProjectRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute(
        project: Project,
        subtitleId: UUID,
        positionXRatio: Double,
        positionYRatio: Double
    ) async throws {
        guard let subtitle = project.subtitles.first(where: { $0.id == subtitleId }) else {
            throw UpdateSubtitlePositionError.subtitleNotFound
        }

        subtitle.positionXRatio = min(max(positionXRatio, 0), 1)
        subtitle.positionYRatio = min(max(positionYRatio, 0), 1)
        try await repository.save(project)
    }
}
