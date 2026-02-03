import Foundation

final class MockTemplateRepository: TemplateRepositoryProtocol, Sendable {

    // MARK: - Properties

    private let templates: [TemplateDTO]

    // MARK: - Init

    init() {
        templates = Self.createMockTemplates()
    }

    // MARK: - TemplateRepositoryProtocol

    func fetchAll() async throws -> [TemplateDTO] {
        try await simulateNetworkDelay()
        return templates
    }

    func fetch(by id: String) async throws -> TemplateDTO? {
        try await simulateNetworkDelay()
        return templates.first { $0.id == id }
    }

    // MARK: - Private Methods

    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
    }

    private static func createMockTemplates() -> [TemplateDTO] {
        [
            TemplateDTO(
                id: "daily-vlog",
                name: "1日のVlog",
                description: "朝から夜までの1日を記録するテンプレート",
                referenceVideoUrl: "https://youtube.com/example1",
                explanation: "朝→昼→夜の流れで、日常の何気ない瞬間を切り取ります",
                segments: [
                    SegmentDTO(order: 0, startSec: 0, endSec: 5, description: "オープニング"),
                    SegmentDTO(order: 1, startSec: 5, endSec: 15, description: "朝の様子"),
                    SegmentDTO(order: 2, startSec: 15, endSec: 30, description: "昼の活動"),
                    SegmentDTO(order: 3, startSec: 30, endSec: 45, description: "夜のシーン"),
                    SegmentDTO(order: 4, startSec: 45, endSec: 50, description: "エンディング")
                ]
            ),
            TemplateDTO(
                id: "travel-vlog",
                name: "旅行Vlog",
                description: "旅行の思い出を記録するテンプレート",
                referenceVideoUrl: "https://youtube.com/example2",
                explanation: "出発から帰宅まで、旅のハイライトを凝縮します",
                segments: [
                    SegmentDTO(order: 0, startSec: 0, endSec: 5, description: "タイトル・行き先紹介"),
                    SegmentDTO(order: 1, startSec: 5, endSec: 20, description: "移動シーン"),
                    SegmentDTO(order: 2, startSec: 20, endSec: 40, description: "メインの観光地"),
                    SegmentDTO(order: 3, startSec: 40, endSec: 55, description: "グルメ・お土産"),
                    SegmentDTO(order: 4, startSec: 55, endSec: 60, description: "エンディング・感想")
                ]
            ),
            TemplateDTO(
                id: "cooking-vlog",
                name: "料理Vlog",
                description: "料理の過程を記録するテンプレート",
                referenceVideoUrl: "https://youtube.com/example3",
                explanation: "材料紹介から完成まで、料理の楽しさを伝えます",
                segments: [
                    SegmentDTO(order: 0, startSec: 0, endSec: 5, description: "今日作るもの紹介"),
                    SegmentDTO(order: 1, startSec: 5, endSec: 15, description: "材料紹介"),
                    SegmentDTO(order: 2, startSec: 15, endSec: 35, description: "調理過程"),
                    SegmentDTO(order: 3, startSec: 35, endSec: 45, description: "完成・盛り付け"),
                    SegmentDTO(order: 4, startSec: 45, endSec: 50, description: "実食・感想")
                ]
            )
        ]
    }
}
