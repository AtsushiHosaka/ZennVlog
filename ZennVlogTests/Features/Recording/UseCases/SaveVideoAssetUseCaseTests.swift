import Foundation
import Testing
@testable import ZennVlog

@Suite("SaveVideoAssetUseCase テスト")
@MainActor
struct SaveVideoAssetUseCaseTests {
    let useCase: SaveVideoAssetUseCase
    let mockRepository: MockProjectRepository

    init() async throws {
        mockRepository = MockProjectRepository(emptyForTesting: true)
        useCase = SaveVideoAssetUseCase(repository: mockRepository)
    }

    // MARK: - ヘルパー

    private func createTestProject() -> Project {
        Project(
            name: "テスト用Vlog",
            template: Template(segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング"),
                Segment(order: 1, startSeconds: 5, endSeconds: 15, segmentDescription: "メインシーン"),
                Segment(order: 2, startSeconds: 15, endSeconds: 25, segmentDescription: "エンディング")
            ]),
            status: .recording
        )
    }

    // MARK: - テスト

    @Test("セグメントに動画素材を保存できる")
    func セグメントに動画素材を保存できる() async throws {
        // Given
        let project = createTestProject()
        try await mockRepository.save(project)

        // When
        try await useCase.execute(
            project: project,
            localFileURL: "mock://video1.mp4",
            duration: 5.0,
            segmentOrder: 0
        )

        // Then
        #expect(project.videoAssets.count == 1)
        #expect(project.videoAssets.first?.segmentOrder == 0)
        #expect(project.videoAssets.first?.localFileURL == "mock://video1.mp4")
        #expect(project.videoAssets.first?.duration == 5.0)
    }

    @Test("segmentOrderがnilの場合ストック動画として保存される")
    func segmentOrderがnilの場合ストック動画として保存される() async throws {
        // Given
        let project = createTestProject()
        try await mockRepository.save(project)

        // When
        try await useCase.execute(
            project: project,
            localFileURL: "mock://stock.mp4",
            duration: 10.0,
            segmentOrder: nil
        )

        // Then
        #expect(project.videoAssets.count == 1)
        #expect(project.videoAssets.first?.segmentOrder == nil)
    }

    @Test("同じsegmentOrderの既存動画を上書きする")
    func 同じsegmentOrderの既存動画を上書きする() async throws {
        // Given
        let project = createTestProject()
        try await mockRepository.save(project)

        try await useCase.execute(
            project: project,
            localFileURL: "mock://old.mp4",
            duration: 5.0,
            segmentOrder: 0
        )
        #expect(project.videoAssets.count == 1)

        // When
        try await useCase.execute(
            project: project,
            localFileURL: "mock://new.mp4",
            duration: 5.0,
            segmentOrder: 0
        )

        // Then
        #expect(project.videoAssets.count == 1)
        #expect(project.videoAssets.first?.localFileURL == "mock://new.mp4")
    }

    @Test("保存後にupdatedAtが更新される")
    func 保存後にupdatedAtが更新される() async throws {
        // Given
        let project = createTestProject()
        let originalUpdatedAt = project.updatedAt
        try await mockRepository.save(project)

        // When
        try await useCase.execute(
            project: project,
            localFileURL: "mock://video.mp4",
            duration: 5.0,
            segmentOrder: 0
        )

        // Then
        #expect(project.updatedAt >= originalUpdatedAt)
    }

    @Test("trimStartSecondsが正しく保存される")
    func trimStartSecondsが正しく保存される() async throws {
        // Given
        let project = createTestProject()
        try await mockRepository.save(project)

        // When
        try await useCase.execute(
            project: project,
            localFileURL: "mock://video.mp4",
            duration: 5.0,
            segmentOrder: 0,
            trimStartSeconds: 3.5
        )

        // Then
        #expect(project.videoAssets.first?.trimStartSeconds == 3.5)
    }

    @Test("複数セグメントに保存できる")
    func 複数セグメントに保存できる() async throws {
        // Given
        let project = createTestProject()
        try await mockRepository.save(project)

        // When
        try await useCase.execute(
            project: project,
            localFileURL: "mock://video1.mp4",
            duration: 5.0,
            segmentOrder: 0
        )
        try await useCase.execute(
            project: project,
            localFileURL: "mock://video2.mp4",
            duration: 10.0,
            segmentOrder: 1
        )
        try await useCase.execute(
            project: project,
            localFileURL: "mock://video3.mp4",
            duration: 10.0,
            segmentOrder: 2
        )

        // Then
        #expect(project.videoAssets.count == 3)
        let orders = Set(project.videoAssets.compactMap { $0.segmentOrder })
        #expect(orders == Set([0, 1, 2]))
    }

    @Test("リポジトリのsaveが呼ばれる")
    func リポジトリのsaveが呼ばれる() async throws {
        // Given
        let project = createTestProject()

        // When
        try await useCase.execute(
            project: project,
            localFileURL: "mock://video.mp4",
            duration: 5.0,
            segmentOrder: 0
        )

        // Then
        let fetched = try await mockRepository.fetch(by: project.id)
        #expect(fetched != nil)
        #expect(fetched?.videoAssets.count == 1)
    }
}
