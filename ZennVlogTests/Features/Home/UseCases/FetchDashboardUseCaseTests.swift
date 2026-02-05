import Testing
@testable import ZennVlog

@Suite("FetchDashboardUseCase Tests")
@MainActor
struct FetchDashboardUseCaseTests {

    let useCase: FetchDashboardUseCase
    let mockRepository: MockProjectRepository

    init() async {
        mockRepository = MockProjectRepository()
        useCase = FetchDashboardUseCase(repository: mockRepository)
    }

    // MARK: - 基本的な取得テスト

    @Test("成功時にダッシュボードデータを返す")
    func 成功時にダッシュボードデータを返す() async throws {
        // Given: プロジェクトが存在する
        // MockProjectRepositoryのデフォルトデータを使用

        // When: ダッシュボードを取得
        let result = try await useCase.execute()

        // Then: データが返される
        #expect(result.inProgressProjects != nil)
        #expect(result.recentProjects != nil)
        #expect(result.completedProjects != nil)
    }

    @Test("リポジトリエラー時にエラーをthrowする")
    func リポジトリエラー時にエラーをthrowする() async throws {
        // Given: リポジトリがエラーを返す
        mockRepository.shouldThrowError = true

        // When & Then: エラーがthrowされる
        await #expect(throws: Error.self) {
            try await useCase.execute()
        }
    }

    // MARK: - 進行中プロジェクトのテスト

    @Test("進行中プロジェクトを正しく分類")
    func 進行中プロジェクトを正しく分類() async throws {
        // Given: recording状態で未完了セグメントがあるプロジェクト
        let template = Template(segments: [
            Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング"),
            Segment(order: 1, startSeconds: 5, endSeconds: 15, segmentDescription: "メイン"),
            Segment(order: 2, startSeconds: 15, endSeconds: 20, segmentDescription: "エンディング")
        ])

        let project = Project(
            name: "進行中Vlog",
            theme: "テスト",
            projectDescription: "テスト用プロジェクト",
            template: template,
            videoAssets: [
                VideoAsset(segmentOrder: 0, localFileURL: "mock://video1.mp4", duration: 5)
                // セグメント1と2は未撮影
            ],
            status: .recording
        )

        try await mockRepository.save(project)

        // When: ダッシュボードを取得
        let result = try await useCase.execute()

        // Then: 進行中プロジェクトに分類される
        #expect(result.inProgressProjects.count == 1)
        #expect(result.inProgressProjects.first?.projectId == project.id)
        #expect(result.inProgressProjects.first?.name == "進行中Vlog")
    }

    @Test("次に撮る素材を正しく判定")
    func 次に撮る素材を正しく判定() async throws {
        // Given: セグメント0は撮影済み、1が次に撮るべき
        let template = Template(segments: [
            Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング"),
            Segment(order: 1, startSeconds: 5, endSeconds: 15, segmentDescription: "メイン"),
            Segment(order: 2, startSeconds: 15, endSeconds: 20, segmentDescription: "エンディング")
        ])

        let project = Project(
            name: "進行中Vlog",
            template: template,
            videoAssets: [
                VideoAsset(segmentOrder: 0, localFileURL: "mock://video1.mp4", duration: 5)
            ],
            status: .recording
        )

        try await mockRepository.save(project)

        // When: ダッシュボードを取得
        let result = try await useCase.execute()

        // Then: 次に撮る素材が正しく判定される
        let inProgress = try #require(result.inProgressProjects.first)
        #expect(inProgress.nextSegmentOrder == 1)
        #expect(inProgress.nextSegmentDescription == "メイン")
    }

    @Test("すべてのセグメントが撮影済みの場合は進行中に含めない")
    func すべてのセグメントが撮影済みの場合は進行中に含めない() async throws {
        // Given: すべてのセグメントが撮影済み
        let template = Template(segments: [
            Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング"),
            Segment(order: 1, startSeconds: 5, endSeconds: 15, segmentDescription: "メイン")
        ])

        let project = Project(
            name: "完了間近Vlog",
            template: template,
            videoAssets: [
                VideoAsset(segmentOrder: 0, localFileURL: "mock://video1.mp4", duration: 5),
                VideoAsset(segmentOrder: 1, localFileURL: "mock://video2.mp4", duration: 10)
            ],
            status: .recording
        )

        try await mockRepository.save(project)

        // When: ダッシュボードを取得
        let result = try await useCase.execute()

        // Then: 進行中プロジェクトに含まれない
        #expect(result.inProgressProjects.count == 0)
    }

    @Test("recording状態でない場合は進行中に含めない")
    func recording状態でない場合は進行中に含めない() async throws {
        // Given: editing状態のプロジェクト（未完了セグメントあり）
        let template = Template(segments: [
            Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング")
        ])

        let project = Project(
            name: "編集中Vlog",
            template: template,
            videoAssets: [],
            status: .editing
        )

        try await mockRepository.save(project)

        // When: ダッシュボードを取得
        let result = try await useCase.execute()

        // Then: 進行中プロジェクトに含まれない
        #expect(result.inProgressProjects.count == 0)
    }

    @Test("進捗率を正しく計算")
    func 進捗率を正しく計算() async throws {
        // Given: 3セグメント中2つ撮影済み
        let template = Template(segments: [
            Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング"),
            Segment(order: 1, startSeconds: 5, endSeconds: 15, segmentDescription: "メイン"),
            Segment(order: 2, startSeconds: 15, endSeconds: 20, segmentDescription: "エンディング")
        ])

        let project = Project(
            name: "進行中Vlog",
            template: template,
            videoAssets: [
                VideoAsset(segmentOrder: 0, localFileURL: "mock://video1.mp4", duration: 5),
                VideoAsset(segmentOrder: 1, localFileURL: "mock://video2.mp4", duration: 10)
            ],
            status: .recording
        )

        try await mockRepository.save(project)

        // When: ダッシュボードを取得
        let result = try await useCase.execute()

        // Then: 進捗率が2/3
        let inProgress = try #require(result.inProgressProjects.first)
        #expect(inProgress.completedSegments == 2)
        #expect(inProgress.totalSegments == 3)
    }

    // MARK: - 最近のプロジェクトのテスト

    @Test("最近のプロジェクトをupdatedAtでソート")
    func 最近のプロジェクトをupdatedAtでソート() async throws {
        // Given: 更新日時が異なる3つのプロジェクト
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let twoDaysAgo = now.addingTimeInterval(-86400 * 2)

        let project1 = Project(name: "最新", status: .recording, updatedAt: now)
        let project2 = Project(name: "昨日", status: .recording, updatedAt: yesterday)
        let project3 = Project(name: "一昨日", status: .recording, updatedAt: twoDaysAgo)

        try await mockRepository.save(project3)
        try await mockRepository.save(project1)
        try await mockRepository.save(project2)

        // When: ダッシュボードを取得
        let result = try await useCase.execute()

        // Then: 新しい順にソートされている
        #expect(result.recentProjects.count >= 3)
        #expect(result.recentProjects[0].name == "最新")
        #expect(result.recentProjects[1].name == "昨日")
        #expect(result.recentProjects[2].name == "一昨日")
    }

    @Test("最近のプロジェクトは最大10件")
    func 最近のプロジェクトは最大10件() async throws {
        // Given: 15個のプロジェクト
        for i in 0..<15 {
            let project = Project(
                name: "Project \(i)",
                status: .recording,
                updatedAt: Date().addingTimeInterval(Double(-i * 3600))
            )
            try await mockRepository.save(project)
        }

        // When: ダッシュボードを取得
        let result = try await useCase.execute()

        // Then: 最大10件まで
        #expect(result.recentProjects.count <= 10)
    }

    @Test("最近のプロジェクトにはすべての状態を含む")
    func 最近のプロジェクトにはすべての状態を含む() async throws {
        // Given: 異なる状態のプロジェクト
        let chatting = Project(name: "チャット中", status: .chatting, updatedAt: Date())
        let recording = Project(name: "撮影中", status: .recording, updatedAt: Date().addingTimeInterval(-3600))
        let editing = Project(name: "編集中", status: .editing, updatedAt: Date().addingTimeInterval(-7200))
        let completed = Project(name: "完成", status: .completed, updatedAt: Date().addingTimeInterval(-10800))

        try await mockRepository.save(chatting)
        try await mockRepository.save(recording)
        try await mockRepository.save(editing)
        try await mockRepository.save(completed)

        // When: ダッシュボードを取得
        let result = try await useCase.execute()

        // Then: すべての状態が含まれる
        #expect(result.recentProjects.count >= 4)
        #expect(result.recentProjects.contains { $0.status == .chatting })
        #expect(result.recentProjects.contains { $0.status == .recording })
        #expect(result.recentProjects.contains { $0.status == .editing })
        #expect(result.recentProjects.contains { $0.status == .completed })
    }

    // MARK: - 完成したVlogのテスト

    @Test("完成したVlogを正しく分類")
    func 完成したVlogを正しく分類() async throws {
        // Given: completed状態のプロジェクト
        let completed1 = Project(name: "完成Vlog 1", status: .completed)
        let completed2 = Project(name: "完成Vlog 2", status: .completed)
        let recording = Project(name: "撮影中Vlog", status: .recording)

        try await mockRepository.save(completed1)
        try await mockRepository.save(completed2)
        try await mockRepository.save(recording)

        // When: ダッシュボードを取得
        let result = try await useCase.execute()

        // Then: completed状態のみが含まれる
        #expect(result.completedProjects.count == 2)
        #expect(result.completedProjects.allSatisfy { $0.status == .completed })
    }

    @Test("完成したVlogは作成日時でソート")
    func 完成したVlogは作成日時でソート() async throws {
        // Given: 作成日時が異なる完成プロジェクト
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)

        let newer = Project(name: "新しい", status: .completed, createdAt: now)
        let older = Project(name: "古い", status: .completed, createdAt: yesterday)

        try await mockRepository.save(older)
        try await mockRepository.save(newer)

        // When: ダッシュボードを取得
        let result = try await useCase.execute()

        // Then: 新しい順にソートされている
        #expect(result.completedProjects.first?.name == "新しい")
    }

    // MARK: - エッジケースのテスト

    @Test("プロジェクトが0件の場合")
    func プロジェクトが0件の場合() async throws {
        // Given: プロジェクトが存在しない（Mockのデータをクリア）
        let allProjects = try await mockRepository.fetchAll()
        for project in allProjects {
            try await mockRepository.delete(project)
        }

        // When: ダッシュボードを取得
        let result = try await useCase.execute()

        // Then: 空の配列が返される
        #expect(result.inProgressProjects.count == 0)
        #expect(result.recentProjects.count == 0)
        #expect(result.completedProjects.count == 0)
    }

    @Test("テンプレートがnilの場合でもエラーにならない")
    func テンプレートがnilの場合でもエラーにならない() async throws {
        // Given: テンプレートなしのプロジェクト
        let project = Project(
            name: "テンプレートなし",
            template: nil,
            status: .recording
        )

        try await mockRepository.save(project)

        // When & Then: エラーなく実行される
        let result = try await useCase.execute()
        #expect(result != nil)
    }

    @Test("videoAssetsが空の場合")
    func videoAssetsが空の場合() async throws {
        // Given: videoAssetsが空のプロジェクト
        let template = Template(segments: [
            Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング")
        ])

        let project = Project(
            name: "動画なし",
            template: template,
            videoAssets: [],
            status: .recording
        )

        try await mockRepository.save(project)

        // When: ダッシュボードを取得
        let result = try await useCase.execute()

        // Then: 進行中プロジェクトに含まれる（未撮影セグメントあり）
        #expect(result.inProgressProjects.contains { $0.name == "動画なし" })
        #expect(result.inProgressProjects.first?.completedSegments == 0)
    }

    @Test("segmentOrderがnilのVideoAssetは進捗にカウントしない")
    func segmentOrderがnilのVideoAssetは進捗にカウントしない() async throws {
        // Given: segmentOrderがnilのVideoAsset（ストック動画）を含む
        let template = Template(segments: [
            Segment(order: 0, startSeconds: 0, endSeconds: 5, segmentDescription: "オープニング")
        ])

        let project = Project(
            name: "ストック動画あり",
            template: template,
            videoAssets: [
                VideoAsset(segmentOrder: nil, localFileURL: "mock://stock.mp4", duration: 10),
                VideoAsset(segmentOrder: 0, localFileURL: "mock://video1.mp4", duration: 5)
            ],
            status: .recording
        )

        try await mockRepository.save(project)

        // When: ダッシュボードを取得
        let result = try await useCase.execute()

        // Then: ストック動画は進捗にカウントされない
        let inProgress = try #require(result.inProgressProjects.first { $0.name == "ストック動画あり" })
        #expect(inProgress.completedSegments == 1) // セグメント0のみ
    }
}
