import Foundation
import Testing
@testable import ZennVlog

@Suite("UpdateSubtitlePositionUseCase テスト")
@MainActor
struct UpdateSubtitlePositionUseCaseTests {
    let useCase: UpdateSubtitlePositionUseCase
    let repository: MockProjectRepository

    init() async throws {
        repository = MockProjectRepository(emptyForTesting: true)
        useCase = UpdateSubtitlePositionUseCase(repository: repository)
    }

    @Test("字幕位置を保存できる")
    func updatePosition() async throws {
        let subtitle = Subtitle(startSeconds: 0, endSeconds: 2, text: "A")
        let project = Project(
            name: "テスト",
            template: Template(segments: [Segment(order: 0, startSeconds: 0, endSeconds: 4, segmentDescription: "")]),
            subtitles: [subtitle]
        )

        try await useCase.execute(
            project: project,
            subtitleId: subtitle.id,
            positionXRatio: 0.25,
            positionYRatio: 0.4
        )

        #expect(subtitle.positionXRatio == 0.25)
        #expect(subtitle.positionYRatio == 0.4)
    }

    @Test("比率は0...1にクランプされる")
    func clampPosition() async throws {
        let subtitle = Subtitle(startSeconds: 0, endSeconds: 2, text: "A")
        let project = Project(name: "テスト", subtitles: [subtitle])

        try await useCase.execute(
            project: project,
            subtitleId: subtitle.id,
            positionXRatio: 1.5,
            positionYRatio: -0.3
        )

        #expect(subtitle.positionXRatio == 1.0)
        #expect(subtitle.positionYRatio == 0.0)
    }

    @Test("対象字幕がない場合はエラー")
    func subtitleNotFound() async {
        let project = Project(name: "テスト")

        do {
            try await useCase.execute(
                project: project,
                subtitleId: UUID(),
                positionXRatio: 0.5,
                positionYRatio: 0.5
            )
            #expect(Bool(false), "字幕なしはエラーになるべき")
        } catch let error as UpdateSubtitlePositionError {
            #expect(error == .subtitleNotFound)
        } catch {
            #expect(Bool(false), "UpdateSubtitlePositionError が返るべき")
        }
    }
}
