import Foundation

@MainActor
final class CreateProjectFromTemplateUseCase {

    // MARK: - Properties

    private let repository: ProjectRepositoryProtocol

    // MARK: - Init

    init(repository: ProjectRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute(
        preferredName: String?,
        templateDTO: TemplateDTO,
        bgm: BGMTrack?
    ) async throws -> Project {
        let template = Template(
            firestoreTemplateId: templateDTO.id,
            segments: templateDTO.segments
                .sorted { $0.order < $1.order }
                .map {
                    Segment(
                        order: $0.order,
                        startSeconds: $0.startSec,
                        endSeconds: $0.endSec,
                        segmentDescription: $0.description
                    )
                }
        )

        let projectName = normalizedProjectName(preferredName, fallback: templateDTO.name)
        let project = Project(
            name: projectName,
            theme: templateDTO.name,
            projectDescription: templateDTO.description,
            template: template,
            selectedBGMId: bgm?.id,
            status: .recording
        )

        try await repository.save(project)
        return project
    }

    // MARK: - Private Methods

    private func normalizedProjectName(_ preferredName: String?, fallback: String) -> String {
        let trimmed = preferredName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }
}
