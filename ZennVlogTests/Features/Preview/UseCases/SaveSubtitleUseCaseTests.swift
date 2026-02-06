import Foundation
import Testing
@testable import ZennVlog

@Suite("SaveSubtitleUseCase テスト")
@MainActor
struct SaveSubtitleUseCaseTests {
    let useCase: SaveSubtitleUseCase
    let mockRepository: MockProjectRepository

    init() async throws {
        mockRepository = MockProjectRepository()
        useCase = SaveSubtitleUseCase(repository: mockRepository)
    }

    @Test("新規テロップを保存できる")
    func saveNewSubtitle() async throws {
        let project = Project(
            name: "テスト用",
            template: Template(segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "テスト")
            ])
        )
        try await mockRepository.save(project)

        try await useCase.execute(
            project: project,
            segmentOrder: 0,
            text: "こんにちは"
        )

        let saved = try await mockRepository.fetch(by: project.id)
        #expect(saved?.subtitles.count == 1)
        #expect(saved?.subtitles.first?.text == "こんにちは")
    }

    @Test("保存後にProjectが更新される")
    func projectUpdatedAfterSave() async throws {
        let project = Project(
            name: "テスト用",
            template: Template(segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "テスト")
            ])
        )
        try await mockRepository.save(project)

        #expect(project.subtitles.isEmpty)

        try await useCase.execute(
            project: project,
            segmentOrder: 0,
            text: "テストテロップ"
        )

        #expect(!project.subtitles.isEmpty)
        #expect(project.subtitles.first?.segmentOrder == 0)
    }

    @Test("既存テロップを上書きできる")
    func updateExistingSubtitle() async throws {
        let project = Project(
            name: "テスト用",
            template: Template(segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "テスト")
            ]),
            subtitles: [
                Subtitle(segmentOrder: 0, text: "古いテキスト")
            ]
        )
        try await mockRepository.save(project)

        try await useCase.execute(
            project: project,
            segmentOrder: 0,
            text: "新しいテキスト"
        )

        let saved = try await mockRepository.fetch(by: project.id)
        #expect(saved?.subtitles.count == 1)
        #expect(saved?.subtitles.first?.text == "新しいテキスト")
    }

    @Test("同じセグメントのテロップは1つのみ")
    func onlyOneSubtitlePerSegment() async throws {
        let project = Project(
            name: "テスト用",
            template: Template(segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "テスト")
            ])
        )
        try await mockRepository.save(project)

        try await useCase.execute(
            project: project,
            segmentOrder: 0,
            text: "最初のテキスト"
        )

        try await useCase.execute(
            project: project,
            segmentOrder: 0,
            text: "2番目のテキスト"
        )

        let saved = try await mockRepository.fetch(by: project.id)
        let subtitlesForSegment0 = saved?.subtitles.filter { $0.segmentOrder == 0 }
        #expect(subtitlesForSegment0?.count == 1)
        #expect(subtitlesForSegment0?.first?.text == "2番目のテキスト")
    }

    @Test("空のテキストでも保存できる")
    func saveEmptyText() async throws {
        let project = Project(
            name: "テスト用",
            template: Template(segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "テスト")
            ])
        )
        try await mockRepository.save(project)

        try await useCase.execute(
            project: project,
            segmentOrder: 0,
            text: ""
        )

        let saved = try await mockRepository.fetch(by: project.id)
        #expect(saved?.subtitles.count == 1)
        #expect(saved?.subtitles.first?.text == "")
    }

    @Test("複数セグメントに異なるテロップを保存")
    func saveMultipleSubtitles() async throws {
        let project = Project(
            name: "テスト用",
            template: Template(segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング"),
                Segment(order: 1, startSeconds: 5, endSeconds: 10, segmentDescription: "メイン"),
                Segment(order: 2, startSeconds: 10, endSeconds: 15, segmentDescription: "エンディング")
            ])
        )
        try await mockRepository.save(project)

        try await useCase.execute(
            project: project,
            segmentOrder: 0,
            text: "オープニングテロップ"
        )

        try await useCase.execute(
            project: project,
            segmentOrder: 1,
            text: "メインテロップ"
        )

        try await useCase.execute(
            project: project,
            segmentOrder: 2,
            text: "エンディングテロップ"
        )

        let saved = try await mockRepository.fetch(by: project.id)
        #expect(saved?.subtitles.count == 3)

        let subtitle0 = saved?.subtitles.first { $0.segmentOrder == 0 }
        let subtitle1 = saved?.subtitles.first { $0.segmentOrder == 1 }
        let subtitle2 = saved?.subtitles.first { $0.segmentOrder == 2 }

        #expect(subtitle0?.text == "オープニングテロップ")
        #expect(subtitle1?.text == "メインテロップ")
        #expect(subtitle2?.text == "エンディングテロップ")
    }
}
