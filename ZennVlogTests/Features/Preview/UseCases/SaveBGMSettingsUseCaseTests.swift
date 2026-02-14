import Foundation
import Testing
@testable import ZennVlog

@Suite("SaveBGMSettingsUseCase テスト")
@MainActor
struct SaveBGMSettingsUseCaseTests {
    let useCase: SaveBGMSettingsUseCase
    let repository: MockProjectRepository

    init() async throws {
        repository = MockProjectRepository(emptyForTesting: true)
        useCase = SaveBGMSettingsUseCase(repository: repository)
    }

    @Test("BGM IDと音量を保存できる")
    func saveSettings() async throws {
        let project = Project(name: "テスト")

        try await useCase.execute(
            project: project,
            selectedBGMId: "bgm-001",
            bgmVolume: 0.7
        )

        #expect(project.selectedBGMId == "bgm-001")
        #expect(project.bgmVolume == 0.7)
    }
}
