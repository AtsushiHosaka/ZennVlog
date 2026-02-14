import Foundation
import Testing
@testable import ZennVlog

@Suite("DeleteSubtitleUseCase テスト")
@MainActor
struct DeleteSubtitleUseCaseTests {
    let useCase: DeleteSubtitleUseCase
    let repository: MockProjectRepository

    init() async throws {
        repository = MockProjectRepository(emptyForTesting: true)
        useCase = DeleteSubtitleUseCase(repository: repository)
    }

    @Test("指定したテロップを削除できる")
    func deleteSubtitle() async throws {
        let first = Subtitle(startSeconds: 0, endSeconds: 2, text: "A")
        let second = Subtitle(startSeconds: 3, endSeconds: 5, text: "B")
        let project = Project(
            name: "テスト",
            template: Template(segments: [Segment(order: 0, startSeconds: 0, endSeconds: 6, segmentDescription: "")]),
            subtitles: [first, second]
        )

        try await useCase.execute(project: project, subtitleId: first.id)

        #expect(project.subtitles.count == 1)
        #expect(project.subtitles.first?.id == second.id)
    }
}
