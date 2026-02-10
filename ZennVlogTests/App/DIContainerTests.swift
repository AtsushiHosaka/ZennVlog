import Foundation
import Photos
import Testing
import UIKit
@testable import ZennVlog

@MainActor
private final class ProjectRepositoryStub: ProjectRepositoryProtocol {
    func fetchAll() async throws -> [Project] { [] }
    func fetch(by id: UUID) async throws -> Project? { nil }
    func save(_ project: Project) async throws {}
    func delete(_ project: Project) async throws {}
}

private actor TemplateRepositoryStub: TemplateRepositoryProtocol {
    func fetchAll() async throws -> [TemplateDTO] { [] }
    func fetch(by id: String) async throws -> TemplateDTO? { nil }
}

private actor BGMRepositoryStub: BGMRepositoryProtocol {
    func fetchAll() async throws -> [BGMTrack] { [] }
    func fetch(by id: String) async throws -> BGMTrack? { nil }
    func downloadURL(for track: BGMTrack) async throws -> URL {
        URL(fileURLWithPath: "/tmp/test.m4a")
    }
}

private actor GeminiRepositoryStub: GeminiRepositoryProtocol {
    func sendMessage(_ message: String, history: [ChatMessageDTO]) async throws -> GeminiChatResponse {
        GeminiChatResponse(text: "ok", suggestedTemplate: nil, suggestedBGM: nil)
    }

    func analyzeVideo(url: URL) async throws -> VideoAnalysisResult {
        VideoAnalysisResult(segments: [])
    }
}

private actor ImagenRepositoryStub: ImagenRepositoryProtocol {
    func generateGuideImage(prompt: String) async throws -> UIImage {
        UIImage()
    }
}

private actor PhotoLibraryServiceStub: PhotoLibraryServiceProtocol {
    func requestAuthorization() async -> PHAuthorizationStatus { .authorized }
    func saveVideo(at url: URL) async throws {}
}

private actor ActivityControllerServiceStub: ActivityControllerServiceProtocol {
    func share(items: [Any]) async -> Bool { true }
}

@Suite("DIContainer Tests")
@MainActor
struct DIContainerTests {

    @Test("preview uses mock repositories")
    func previewUsesMockRepositories() {
        let container = DIContainer.preview

        #expect(container.projectRepository is MockProjectRepository)
        #expect(container.templateRepository is MockTemplateRepository)
        #expect(container.bgmRepository is MockBGMRepository)
        #expect(container.geminiRepository is MockGeminiRepository)
        #expect(container.imagenRepository is MockImagenRepository)
    }

    @Test("non-mock container can use live dependencies without mock types")
    func nonMockCanUseLiveDependencies() {
        let liveDependencies = DIContainer.LiveDependencies(
            projectRepository: ProjectRepositoryStub(),
            templateRepository: TemplateRepositoryStub(),
            bgmRepository: BGMRepositoryStub(),
            geminiRepository: GeminiRepositoryStub(),
            imagenRepository: ImagenRepositoryStub(),
            photoLibraryService: PhotoLibraryServiceStub(),
            activityControllerService: ActivityControllerServiceStub()
        )

        let container = DIContainer(
            useMock: false,
            liveDependencies: liveDependencies
        )

        #expect(!(container.projectRepository is MockProjectRepository))
        #expect(!(container.templateRepository is MockTemplateRepository))
        #expect(!(container.bgmRepository is MockBGMRepository))
        #expect(!(container.geminiRepository is MockGeminiRepository))
        #expect(!(container.imagenRepository is MockImagenRepository))
    }
}
