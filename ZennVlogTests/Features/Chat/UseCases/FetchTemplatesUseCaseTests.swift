import Testing
@testable import ZennVlog

@Suite("FetchTemplatesUseCase Tests")
@MainActor
struct FetchTemplatesUseCaseTests {

    let useCase: FetchTemplatesUseCase
    let mockRepository: MockTemplateRepository

    init() async {
        mockRepository = MockTemplateRepository()
        useCase = FetchTemplatesUseCase(repository: mockRepository)
    }

    // MARK: - 基本的な取得テスト

    @Test("すべてのテンプレートを取得できる")
    func すべてのテンプレートを取得できる() async throws {
        // Given: テンプレートリポジトリ
        // MockTemplateRepositoryのデフォルトデータを使用

        // When: テンプレートを取得
        let templates = try await useCase.execute()

        // Then: テンプレート一覧が返される
        #expect(templates.count == 3)
    }

    @Test("各テンプレートに必要な情報が含まれる")
    func 各テンプレートに必要な情報が含まれる() async throws {
        // Given: テンプレートリポジトリ

        // When: テンプレートを取得
        let templates = try await useCase.execute()

        // Then: 各テンプレートに必要な情報が含まれる
        for template in templates {
            #expect(!template.id.isEmpty)
            #expect(!template.name.isEmpty)
            #expect(!template.description.isEmpty)
            #expect(!template.referenceVideoUrl.isEmpty)
            #expect(!template.explanation.isEmpty)
            #expect(!template.segments.isEmpty)
        }
    }

    @Test("1日のVlogテンプレートが含まれる")
    func 日のVlogテンプレートが含まれる() async throws {
        // Given: テンプレートリポジトリ

        // When: テンプレートを取得
        let templates = try await useCase.execute()

        // Then: 1日のVlogテンプレートが含まれる
        let dailyVlog = try #require(templates.first { $0.id == "daily-vlog" })
        #expect(dailyVlog.name == "1日のVlog")
        #expect(dailyVlog.segments.count == 5)
    }

    @Test("旅行Vlogテンプレートが含まれる")
    func 旅行Vlogテンプレートが含まれる() async throws {
        // Given: テンプレートリポジトリ

        // When: テンプレートを取得
        let templates = try await useCase.execute()

        // Then: 旅行Vlogテンプレートが含まれる
        let travelVlog = try #require(templates.first { $0.id == "travel-vlog" })
        #expect(travelVlog.name == "旅行Vlog")
        #expect(travelVlog.segments.count == 5)
    }

    @Test("料理Vlogテンプレートが含まれる")
    func 料理Vlogテンプレートが含まれる() async throws {
        // Given: テンプレートリポジトリ

        // When: テンプレートを取得
        let templates = try await useCase.execute()

        // Then: 料理Vlogテンプレートが含まれる
        let cookingVlog = try #require(templates.first { $0.id == "cooking-vlog" })
        #expect(cookingVlog.name == "料理Vlog")
        #expect(cookingVlog.segments.count == 5)
    }

    // MARK: - セグメント構造のテスト

    @Test("セグメントが正しく順序付けられている")
    func セグメントが正しく順序付けられている() async throws {
        // Given: テンプレートリポジトリ

        // When: テンプレートを取得
        let templates = try await useCase.execute()

        // Then: 各テンプレートのセグメントが順序通り
        for template in templates {
            for (index, segment) in template.segments.enumerated() {
                #expect(segment.order == index)
            }
        }
    }

    @Test("セグメントの時間が連続している")
    func セグメントの時間が連続している() async throws {
        // Given: テンプレートリポジトリ

        // When: テンプレートを取得
        let templates = try await useCase.execute()

        // Then: 各セグメントの時間が連続している
        for template in templates {
            for i in 0..<template.segments.count - 1 {
                let currentSegment = template.segments[i]
                let nextSegment = template.segments[i + 1]

                // 現在のセグメントの終了時刻が次のセグメントの開始時刻と一致
                #expect(currentSegment.endSec == nextSegment.startSec)
            }
        }
    }

    @Test("すべてのセグメントに説明がある")
    func すべてのセグメントに説明がある() async throws {
        // Given: テンプレートリポジトリ

        // When: テンプレートを取得
        let templates = try await useCase.execute()

        // Then: すべてのセグメントに説明がある
        for template in templates {
            for segment in template.segments {
                #expect(!segment.description.isEmpty)
            }
        }
    }

    @Test("セグメントの時間が正の値である")
    func セグメントの時間が正の値である() async throws {
        // Given: テンプレートリポジトリ

        // When: テンプレートを取得
        let templates = try await useCase.execute()

        // Then: すべてのセグメントの時間が正の値
        for template in templates {
            for segment in template.segments {
                #expect(segment.startSec >= 0)
                #expect(segment.endSec > segment.startSec)
            }
        }
    }

    // MARK: - IDによる取得テスト

    @Test("存在するIDでテンプレートを取得できる")
    func 存在するIDでテンプレートを取得できる() async throws {
        // Given: 存在するテンプレートID
        let templateId = "daily-vlog"

        // When: IDでテンプレートを取得
        let template = try await useCase.executeById(id: templateId)

        // Then: テンプレートが返される
        let result = try #require(template)
        #expect(result.id == templateId)
        #expect(result.name == "1日のVlog")
    }

    @Test("存在しないIDではnilを返す")
    func 存在しないIDではnilを返す() async throws {
        // Given: 存在しないテンプレートID
        let templateId = "non-existent-template"

        // When: IDでテンプレートを取得
        let template = try await useCase.executeById(id: templateId)

        // Then: nilが返される
        #expect(template == nil)
    }

    @Test("空文字列のIDではnilを返す")
    func 空文字列のIDではnilを返す() async throws {
        // Given: 空文字列のID
        let templateId = ""

        // When: IDでテンプレートを取得
        let template = try await useCase.executeById(id: templateId)

        // Then: nilが返される
        #expect(template == nil)
    }

    // MARK: - フィルタリングテスト

    @Test("テンプレートをカテゴリでフィルタできる")
    func テンプレートをカテゴリでフィルタできる() async throws {
        // Given: テンプレートリポジトリ

        // When: すべてのテンプレートを取得
        let allTemplates = try await useCase.execute()

        // Then: 特定のカテゴリ（例：日常）でフィルタできる
        let dailyTemplates = allTemplates.filter { $0.name.contains("日") }
        #expect(!dailyTemplates.isEmpty)
    }

    @Test("テンプレートを名前で検索できる")
    func テンプレートを名前で検索できる() async throws {
        // Given: テンプレートリポジトリ

        // When: すべてのテンプレートを取得
        let allTemplates = try await useCase.execute()

        // Then: 名前で検索できる
        let travelTemplates = allTemplates.filter { $0.name.contains("旅行") }
        #expect(travelTemplates.count == 1)
        #expect(travelTemplates.first?.id == "travel-vlog")
    }

    // MARK: - パフォーマンステスト

    @Test("適切な時間内に取得が完了する")
    func 適切な時間内に取得が完了する() async throws {
        // Given: テンプレートリポジトリ

        // When: テンプレートを取得して時間を計測
        let startTime = ContinuousClock.now
        _ = try await useCase.execute()
        let elapsed = ContinuousClock.now - startTime

        // Then: 2秒以内に完了する（ネットワーク遅延300ms + マージン）
        #expect(elapsed < .seconds(2))
    }

    @Test("複数回呼び出しても一貫した結果を返す")
    func 複数回呼び出しても一貫した結果を返す() async throws {
        // Given: テンプレートリポジトリ

        // When: 3回連続で取得
        let result1 = try await useCase.execute()
        let result2 = try await useCase.execute()
        let result3 = try await useCase.execute()

        // Then: すべて同じ内容が返される
        #expect(result1.count == result2.count)
        #expect(result2.count == result3.count)
        #expect(result1.count == 3)

        // IDも一致する
        let ids1 = result1.map { $0.id }.sorted()
        let ids2 = result2.map { $0.id }.sorted()
        let ids3 = result3.map { $0.id }.sorted()

        #expect(ids1 == ids2)
        #expect(ids2 == ids3)
    }

    // MARK: - エッジケーステスト

    @Test("テンプレートが空でないことを保証")
    func テンプレートが空でないことを保証() async throws {
        // Given: テンプレートリポジトリ

        // When: テンプレートを取得
        let templates = try await useCase.execute()

        // Then: 少なくとも1つのテンプレートが存在する
        #expect(templates.count > 0)
    }

    @Test("各テンプレートが一意のIDを持つ")
    func 各テンプレートが一意のIDを持つ() async throws {
        // Given: テンプレートリポジトリ

        // When: テンプレートを取得
        let templates = try await useCase.execute()

        // Then: すべてのIDが一意
        let ids = templates.map { $0.id }
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count)
    }

    @Test("参考動画URLが有効な形式である")
    func 参考動画URLが有効な形式である() async throws {
        // Given: テンプレートリポジトリ

        // When: テンプレートを取得
        let templates = try await useCase.execute()

        // Then: すべての参考動画URLが有効な形式
        for template in templates {
            #expect(template.referenceVideoUrl.hasPrefix("http"))
        }
    }
}
