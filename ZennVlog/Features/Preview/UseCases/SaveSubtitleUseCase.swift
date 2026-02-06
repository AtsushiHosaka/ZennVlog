import Foundation

@MainActor
final class SaveSubtitleUseCase {

    // MARK: - Properties

    private let repository: ProjectRepositoryProtocol

    // MARK: - Init

    init(repository: ProjectRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute(project: Project, segmentOrder: Int, text: String) async throws {
        // Find or create subtitle for this segment
        if let existingSubtitle = project.subtitles.first(where: { $0.segmentOrder == segmentOrder }) {
            existingSubtitle.text = text
        } else {
            let newSubtitle = Subtitle(segmentOrder: segmentOrder, text: text)
            project.subtitles.append(newSubtitle)
        }

        // Save the project with updated subtitles
        try await repository.save(project)
    }
}
