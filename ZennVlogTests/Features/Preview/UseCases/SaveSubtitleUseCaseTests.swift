import Foundation
import Testing
@testable import ZennVlog

@Suite("SaveSubtitleUseCase テスト")
@MainActor
struct SaveSubtitleUseCaseTests {
    let useCase: SaveSubtitleUseCase
    let mockRepository: MockProjectRepository

    init() async throws {
        mockRepository = MockProjectRepository(emptyForTesting: true)
        useCase = SaveSubtitleUseCase(repository: mockRepository)
    }

    @Test("新規テロップを時間範囲で保存できる")
    func saveNewSubtitle() async throws {
        let project = makeProject()

        try await useCase.execute(
            project: project,
            subtitleId: nil,
            startSeconds: 1,
            endSeconds: 4,
            text: "こんにちは"
        )

        #expect(project.subtitles.count == 1)
        #expect(project.subtitles.first?.startSeconds == 1)
        #expect(project.subtitles.first?.endSeconds == 4)
        #expect(project.subtitles.first?.text == "こんにちは")
    }

    @Test("既存テロップを更新できる")
    func updateExistingSubtitle() async throws {
        let subtitle = Subtitle(startSeconds: 1, endSeconds: 3, text: "古いテキスト")
        let project = makeProject(subtitles: [subtitle])

        try await useCase.execute(
            project: project,
            subtitleId: subtitle.id,
            startSeconds: 2,
            endSeconds: 5,
            text: "新しいテキスト"
        )

        #expect(project.subtitles.count == 1)
        #expect(project.subtitles.first?.id == subtitle.id)
        #expect(project.subtitles.first?.startSeconds == 2)
        #expect(project.subtitles.first?.endSeconds == 5)
        #expect(project.subtitles.first?.text == "新しいテキスト")
    }

    @Test("重複範囲は保存できない")
    func rejectOverlap() async throws {
        let project = makeProject(
            subtitles: [
                Subtitle(startSeconds: 2, endSeconds: 5, text: "既存テロップ")
            ]
        )

        do {
            try await useCase.execute(
                project: project,
                subtitleId: nil,
                startSeconds: 4,
                endSeconds: 6,
                text: "重複するテロップ"
            )
            #expect(Bool(false), "重複時はエラーになるべき")
        } catch let error as SaveSubtitleError {
            #expect(error == .overlap)
        }
    }

    @Test("範囲が不正な場合は保存できない")
    func rejectInvalidRange() async throws {
        let project = makeProject()

        do {
            try await useCase.execute(
                project: project,
                subtitleId: nil,
                startSeconds: 3,
                endSeconds: 2,
                text: "不正"
            )
            #expect(Bool(false), "end <= start はエラーになるべき")
        } catch let error as SaveSubtitleError {
            #expect(error == .invalidRange)
        }
    }

    @Test("範囲外は保存できない")
    func rejectOutOfBoundsRange() async throws {
        let project = makeProject() // duration = 12

        do {
            try await useCase.execute(
                project: project,
                subtitleId: nil,
                startSeconds: 11,
                endSeconds: 13,
                text: "範囲外"
            )
            #expect(Bool(false), "動画長を超える範囲はエラーになるべき")
        } catch let error as SaveSubtitleError {
            #expect(error == .rangeOutOfBounds)
        }
    }

    @Test("空テキストは保存できない")
    func rejectEmptyText() async throws {
        let project = makeProject()

        do {
            try await useCase.execute(
                project: project,
                subtitleId: nil,
                startSeconds: 1,
                endSeconds: 2,
                text: "   "
            )
            #expect(Bool(false), "空テキストはエラーになるべき")
        } catch let error as SaveSubtitleError {
            #expect(error == .emptyText)
        }
    }

    // MARK: - Helpers

    private func makeProject(subtitles: [Subtitle] = []) -> Project {
        Project(
            name: "テスト用",
            template: Template(
                segments: [
                    Segment(order: 0, startSeconds: 0, endSeconds: 4, segmentDescription: "A"),
                    Segment(order: 1, startSeconds: 4, endSeconds: 8, segmentDescription: "B"),
                    Segment(order: 2, startSeconds: 8, endSeconds: 12, segmentDescription: "C")
                ]
            ),
            subtitles: subtitles
        )
    }
}
