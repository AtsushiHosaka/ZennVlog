import Foundation

enum SaveSubtitleError: LocalizedError, Equatable {
    case emptyText
    case invalidRange
    case rangeOutOfBounds
    case overlap

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "テロップを入力してください"
        case .invalidRange:
            return "開始時刻と終了時刻の指定が不正です"
        case .rangeOutOfBounds:
            return "動画の時間範囲内で指定してください"
        case .overlap:
            return "他のテロップと時間が重なっています"
        }
    }
}

@MainActor
final class SaveSubtitleUseCase {

    // MARK: - Properties

    private let repository: ProjectRepositoryProtocol

    // MARK: - Init

    init(repository: ProjectRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute(
        project: Project,
        subtitleId: UUID?,
        startSeconds: Double,
        endSeconds: Double,
        text: String
    ) async throws {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw SaveSubtitleError.emptyText
        }
        guard endSeconds > startSeconds else {
            throw SaveSubtitleError.invalidRange
        }

        let maxDuration = project.template?.segments.map(\.endSeconds).max() ?? 0

        if maxDuration > 0 {
            guard startSeconds >= 0, endSeconds <= maxDuration else {
                throw SaveSubtitleError.rangeOutOfBounds
            }
        }

        let hasOverlap = project.subtitles.contains { subtitle in
            if let subtitleId, subtitle.id == subtitleId {
                return false
            }
            return startSeconds < subtitle.endSeconds && endSeconds > subtitle.startSeconds
        }
        guard !hasOverlap else {
            throw SaveSubtitleError.overlap
        }

        if let subtitleId,
           let existingSubtitle = project.subtitles.first(where: { $0.id == subtitleId }) {
            existingSubtitle.startSeconds = startSeconds
            existingSubtitle.endSeconds = endSeconds
            existingSubtitle.text = trimmedText
        } else {
            let newSubtitle = Subtitle(
                id: subtitleId ?? UUID(),
                startSeconds: startSeconds,
                endSeconds: endSeconds,
                text: trimmedText
            )
            project.subtitles.append(newSubtitle)
        }

        try await repository.save(project)
    }
}
