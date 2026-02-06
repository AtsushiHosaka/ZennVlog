import Foundation
import Testing
@testable import ZennVlog

@Suite("DeleteVideoAssetUseCase テスト")
@MainActor
struct DeleteVideoAssetUseCaseTests {
    let useCase: DeleteVideoAssetUseCase
    let mockRepository: MockProjectRepository

    init() async throws {
        mockRepository = MockProjectRepository(emptyForTesting: true)
        useCase = DeleteVideoAssetUseCase(repository: mockRepository)
    }

    // MARK: - ヘルパー

    private func createProjectWithAssets() -> Project {
        Project(
            name: "テスト用Vlog",
            template: Template(segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング"),
                Segment(order: 1, startSeconds: 5, endSeconds: 15, segmentDescription: "メインシーン"),
                Segment(order: 2, startSeconds: 15, endSeconds: 25, segmentDescription: "エンディング")
            ]),
            videoAssets: [
                VideoAsset(segmentOrder: 0, localFileURL: "mock://video1.mp4", duration: 5),
                VideoAsset(segmentOrder: 1, localFileURL: "mock://video2.mp4", duration: 10),
                VideoAsset(segmentOrder: 2, localFileURL: "mock://video3.mp4", duration: 10)
            ],
            status: .recording
        )
    }

    // MARK: - テスト

    @Test("segmentOrderで動画素材を削除できる")
    func segmentOrderで動画素材を削除できる() async throws {
        // Given
        let project = createProjectWithAssets()
        try await mockRepository.save(project)
        #expect(project.videoAssets.count == 3)

        // When
        try await useCase.execute(project: project, segmentOrder: 0)

        // Then
        #expect(project.videoAssets.count == 2)
        #expect(project.videoAssets.contains { $0.segmentOrder == 0 } == false)
    }

    @Test("videoAssetIdで動画素材を削除できる")
    func videoAssetIdで動画素材を削除できる() async throws {
        // Given
        let project = createProjectWithAssets()
        try await mockRepository.save(project)
        let targetId = project.videoAssets[1].id

        // When
        try await useCase.execute(project: project, videoAssetId: targetId)

        // Then
        #expect(project.videoAssets.count == 2)
        #expect(project.videoAssets.contains { $0.id == targetId } == false)
    }

    @Test("削除後にupdatedAtが更新される")
    func 削除後にupdatedAtが更新される() async throws {
        // Given
        let project = createProjectWithAssets()
        let originalUpdatedAt = project.updatedAt
        try await mockRepository.save(project)

        // When
        try await useCase.execute(project: project, segmentOrder: 0)

        // Then
        #expect(project.updatedAt >= originalUpdatedAt)
    }

    @Test("存在しないsegmentOrderで削除しても他の素材に影響しない")
    func 存在しないsegmentOrderで削除しても他の素材に影響しない() async throws {
        // Given
        let project = createProjectWithAssets()
        try await mockRepository.save(project)

        // When
        try await useCase.execute(project: project, segmentOrder: 99)

        // Then
        #expect(project.videoAssets.count == 3)
    }

    @Test("ストック動画をvideoAssetIdで削除できる")
    func ストック動画をvideoAssetIdで削除できる() async throws {
        // Given
        let stockAsset = VideoAsset(segmentOrder: nil, localFileURL: "mock://stock.mp4", duration: 15)
        let project = Project(
            name: "テスト用",
            videoAssets: [stockAsset],
            status: .recording
        )
        try await mockRepository.save(project)

        // When
        try await useCase.execute(project: project, videoAssetId: stockAsset.id)

        // Then
        #expect(project.videoAssets.isEmpty)
    }

    @Test("複数素材がある場合、指定したもののみ削除される")
    func 複数素材がある場合指定したもののみ削除される() async throws {
        // Given
        let project = createProjectWithAssets()
        try await mockRepository.save(project)

        // When
        try await useCase.execute(project: project, segmentOrder: 1)

        // Then
        #expect(project.videoAssets.count == 2)
        let remainingOrders = project.videoAssets.compactMap { $0.segmentOrder }
        #expect(remainingOrders.contains(0))
        #expect(remainingOrders.contains(2))
        #expect(!remainingOrders.contains(1))
    }
}
