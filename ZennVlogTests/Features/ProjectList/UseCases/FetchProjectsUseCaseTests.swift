import Testing
@testable import ZennVlog

@Suite("FetchProjectsUseCase Tests")
@MainActor
struct FetchProjectsUseCaseTests {

    // MARK: - 基本的な取得テスト

    @Test("成功時にプロジェクト一覧を返す")
    func fetchProjectsReturnsListOnSuccess() async throws {
        // Given
        let mockRepository = MockProjectRepository()
        let useCase = FetchProjectsUseCase(repository: mockRepository)

        // When
        let projects = try await useCase.execute()

        // Then
        #expect(!projects.isEmpty)
        #expect(projects.count == 2)
    }

    @Test("空のプロジェクト一覧を返す")
    func fetchProjectsReturnsEmptyList() async throws {
        // Given
        let mockRepository = MockProjectRepository()
        let allProjects = try await mockRepository.fetchAll()
        for project in allProjects {
            try await mockRepository.delete(project)
        }
        let useCase = FetchProjectsUseCase(repository: mockRepository)

        // When
        let projects = try await useCase.execute()

        // Then
        #expect(projects.isEmpty)
        #expect(projects.count == 0)
    }

    @Test("リポジトリエラー時にエラーをthrowする")
    func fetchProjectsThrowsErrorOnRepositoryFailure() async throws {
        // Given
        let mockRepository = MockProjectRepository()
        mockRepository.shouldThrowError = true
        let useCase = FetchProjectsUseCase(repository: mockRepository)

        // When & Then
        #expect(throws: ProjectRepositoryError.self) {
            try await useCase.execute()
        }
    }

    // MARK: - ソートのテスト

    @Test("updatedAt降順でソートされる")
    func fetchProjectsSortsDescendingByUpdatedAt() async throws {
        // Given
        let mockRepository = MockProjectRepository()
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let twoDaysAgo = now.addingTimeInterval(-86400 * 2)

        let recentProject = Project(
            name: "最新のVlog",
            theme: "テスト",
            projectDescription: "最新のテスト用プロジェクト",
            status: .recording,
            updatedAt: now
        )
        let middleProject = Project(
            name: "中間のVlog",
            theme: "テスト",
            projectDescription: "中間のテスト用プロジェクト",
            status: .editing,
            updatedAt: yesterday
        )
        let oldProject = Project(
            name: "古いVlog",
            theme: "テスト",
            projectDescription: "古いテスト用プロジェクト",
            status: .completed,
            updatedAt: twoDaysAgo
        )

        try await mockRepository.save(recentProject)
        try await mockRepository.save(middleProject)
        try await mockRepository.save(oldProject)

        let useCase = FetchProjectsUseCase(repository: mockRepository)

        // When
        let projects = try await useCase.execute()

        // Then
        #expect(projects.count >= 3)
        #expect(projects[0].updatedAt > projects[1].updatedAt)
        #expect(projects[1].updatedAt > projects[2].updatedAt)
        #expect(projects[0].name == "最新のVlog")
    }

    @Test("同じupdatedAtの場合の順序が安定している")
    func fetchProjectsMaintainsStableOrderForEqualDates() async throws {
        // Given
        let mockRepository = MockProjectRepository()
        let fixedDate = Date()

        let project1 = Project(
            name: "プロジェクトA",
            theme: "テスト",
            projectDescription: "テスト用プロジェクトA",
            status: .recording,
            updatedAt: fixedDate
        )
        let project2 = Project(
            name: "プロジェクトB",
            theme: "テスト",
            projectDescription: "テスト用プロジェクトB",
            status: .editing,
            updatedAt: fixedDate
        )

        try await mockRepository.save(project1)
        try await mockRepository.save(project2)

        let useCase = FetchProjectsUseCase(repository: mockRepository)

        // When
        let firstResult = try await useCase.execute()
        let secondResult = try await useCase.execute()

        // Then
        #expect(firstResult.count >= 2)
        #expect(secondResult.count >= 2)
        // 同じupdatedAtの場合、順序が一貫していることを確認
        let firstNames = firstResult.map { $0.name }
        let secondNames = secondResult.map { $0.name }
        #expect(firstNames == secondNames)
    }

    @Test("古いプロジェクトが最後に来る")
    func fetchProjectsPlacesOldestProjectLast() async throws {
        // Given
        let mockRepository = MockProjectRepository()
        let now = Date()
        let thirtyDaysAgo = now.addingTimeInterval(-86400 * 30)

        let recentProject = Project(
            name: "新しいVlog",
            theme: "テスト",
            projectDescription: "新しいテスト用プロジェクト",
            status: .recording,
            updatedAt: now
        )
        let oldProject = Project(
            name: "30日前のVlog",
            theme: "テスト",
            projectDescription: "古いテスト用プロジェクト",
            status: .completed,
            updatedAt: thirtyDaysAgo
        )

        try await mockRepository.save(recentProject)
        try await mockRepository.save(oldProject)

        let useCase = FetchProjectsUseCase(repository: mockRepository)

        // When
        let projects = try await useCase.execute()

        // Then
        #expect(projects.count >= 2)
        #expect(projects.first?.name == "新しいVlog")
        #expect(projects.last?.updatedAt ?? Date() < now)
    }

    // MARK: - エッジケースのテスト

    @Test("大量のプロジェクト50件でもソートされる")
    func fetchProjectsSortsLargeDataset() async throws {
        // Given
        let mockRepository = MockProjectRepository()
        let baseDate = Date()

        for i in 0..<50 {
            let project = Project(
                name: "プロジェクト \(i)",
                theme: "テスト",
                projectDescription: "テスト用プロジェクト \(i)",
                status: .recording,
                updatedAt: baseDate.addingTimeInterval(Double(-i * 3600))
            )
            try await mockRepository.save(project)
        }

        let useCase = FetchProjectsUseCase(repository: mockRepository)

        // When
        let projects = try await useCase.execute()

        // Then
        #expect(projects.count >= 50)
        // 最初のプロジェクトが最新であることを確認
        #expect(projects[0].name == "プロジェクト 0")
        // 全体がソートされていることを確認
        for i in 0..<(projects.count - 1) {
            #expect(projects[i].updatedAt >= projects[i + 1].updatedAt)
        }
    }

    @Test("異なるステータスが混在してもソートされる")
    func fetchProjectsSortsMixedStatuses() async throws {
        // Given
        let mockRepository = MockProjectRepository()
        let now = Date()

        let chattingProject = Project(
            name: "チャット中",
            theme: "テスト",
            status: .chatting,
            updatedAt: now
        )
        let recordingProject = Project(
            name: "録画中",
            theme: "テスト",
            status: .recording,
            updatedAt: now.addingTimeInterval(-3600)
        )
        let editingProject = Project(
            name: "編集中",
            theme: "テスト",
            status: .editing,
            updatedAt: now.addingTimeInterval(-7200)
        )
        let completedProject = Project(
            name: "完了済み",
            theme: "テスト",
            status: .completed,
            updatedAt: now.addingTimeInterval(-10800)
        )

        try await mockRepository.save(chattingProject)
        try await mockRepository.save(recordingProject)
        try await mockRepository.save(editingProject)
        try await mockRepository.save(completedProject)

        let useCase = FetchProjectsUseCase(repository: mockRepository)

        // When
        let projects = try await useCase.execute()

        // Then
        #expect(projects.count >= 4)
        #expect(projects[0].status == .chatting)
        #expect(projects[1].status == .recording)
        #expect(projects[2].status == .editing)
        #expect(projects[3].status == .completed)
    }

    @Test("テンプレートなしプロジェクトも含まれる")
    func fetchProjectsIncludesProjectsWithoutTemplates() async throws {
        // Given
        let mockRepository = MockProjectRepository()

        let projectWithTemplate = Project(
            name: "テンプレート付き",
            theme: "テスト",
            template: Template(segments: [
                Segment(order: 0, startSeconds: 0, endSeconds: 10, segmentDescription: "セグメント1")
            ]),
            status: .recording
        )
        let projectWithoutTemplate = Project(
            name: "テンプレートなし",
            theme: "テスト",
            template: nil,
            status: .recording
        )

        try await mockRepository.save(projectWithTemplate)
        try await mockRepository.save(projectWithoutTemplate)

        let useCase = FetchProjectsUseCase(repository: mockRepository)

        // When
        let projects = try await useCase.execute()

        // Then
        #expect(projects.count >= 2)
        let hasProjectWithTemplate = projects.contains { $0.template != nil }
        let hasProjectWithoutTemplate = projects.contains { $0.template == nil }
        #expect(hasProjectWithTemplate)
        #expect(hasProjectWithoutTemplate)
    }

    @Test("videoAssetsなしプロジェクトも含まれる")
    func fetchProjectsIncludesProjectsWithoutVideoAssets() async throws {
        // Given
        let mockRepository = MockProjectRepository()

        let projectWithAssets = Project(
            name: "アセット付き",
            theme: "テスト",
            videoAssets: [
                VideoAsset(segmentOrder: 0, localFileURL: "mock://video1.mp4", duration: 10)
            ],
            status: .recording
        )
        let projectWithoutAssets = Project(
            name: "アセットなし",
            theme: "テスト",
            videoAssets: [],
            status: .chatting
        )

        try await mockRepository.save(projectWithAssets)
        try await mockRepository.save(projectWithoutAssets)

        let useCase = FetchProjectsUseCase(repository: mockRepository)

        // When
        let projects = try await useCase.execute()

        // Then
        #expect(projects.count >= 2)
        let hasProjectWithAssets = projects.contains { !$0.videoAssets.isEmpty }
        let hasProjectWithoutAssets = projects.contains { $0.videoAssets.isEmpty }
        #expect(hasProjectWithAssets)
        #expect(hasProjectWithoutAssets)
    }

    // MARK: - データ整合性のテスト

    @Test("日本語プロジェクト名が正しく取得される")
    func fetchProjectsPreservesJapaneseText() async throws {
        // Given
        let mockRepository = MockProjectRepository()
        let useCase = FetchProjectsUseCase(repository: mockRepository)

        // When
        let projects = try await useCase.execute()

        // Then
        #expect(projects.count >= 2)
        let weekendProject = projects.first { $0.name == "週末のお出かけVlog" }
        #expect(weekendProject != nil)
        #expect(weekendProject?.name == "週末のお出かけVlog")
        #expect(weekendProject?.theme == "日常")
        #expect(weekendProject?.projectDescription == "週末に友達と出かけた様子を記録")
    }

    @Test("すべてのプロジェクト属性が保持される")
    func fetchProjectsPreservesAllProperties() async throws {
        // Given
        let mockRepository = MockProjectRepository()
        let template = Template(segments: [
            Segment(order: 0, startSeconds: 0, endSeconds: 10, segmentDescription: "テストセグメント")
        ])
        let videoAssets = [
            VideoAsset(segmentOrder: 0, localFileURL: "mock://test.mp4", duration: 10)
        ]

        let testProject = Project(
            name: "完全なプロジェクト",
            theme: "テストテーマ",
            projectDescription: "すべての属性を持つプロジェクト",
            template: template,
            videoAssets: videoAssets,
            status: .editing,
            createdAt: Date().addingTimeInterval(-86400),
            updatedAt: Date()
        )

        try await mockRepository.save(testProject)
        let useCase = FetchProjectsUseCase(repository: mockRepository)

        // When
        let projects = try await useCase.execute()

        // Then
        let savedProject = projects.first { $0.name == "完全なプロジェクト" }
        #expect(savedProject != nil)
        #expect(savedProject?.name == "完全なプロジェクト")
        #expect(savedProject?.theme == "テストテーマ")
        #expect(savedProject?.projectDescription == "すべての属性を持つプロジェクト")
        #expect(savedProject?.template != nil)
        #expect(savedProject?.videoAssets.count == 1)
        #expect(savedProject?.status == .editing)
    }
}
