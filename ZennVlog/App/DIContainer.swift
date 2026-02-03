import Foundation
import Observation

@MainActor
@Observable
final class DIContainer {

    // MARK: - Singleton

    static let shared = DIContainer()

    // MARK: - Properties

    let useMock: Bool

    // MARK: - Init

    init(useMock: Bool = false) {
        #if DEBUG
        self.useMock = ProcessInfo.processInfo.environment["USE_MOCK"] == "true" || useMock
        #else
        self.useMock = false
        #endif
    }

    // MARK: - Repositories

    var projectRepository: any ProjectRepositoryProtocol {
        useMock ? MockProjectRepository() : MockProjectRepository()
        // 本実装後: useMock ? MockProjectRepository() : ProjectRepository()
    }

    var templateRepository: any TemplateRepositoryProtocol {
        useMock ? MockTemplateRepository() : MockTemplateRepository()
        // 本実装後: useMock ? MockTemplateRepository() : TemplateRepository()
    }

    var bgmRepository: any BGMRepositoryProtocol {
        useMock ? MockBGMRepository() : MockBGMRepository()
        // 本実装後: useMock ? MockBGMRepository() : BGMRepository()
    }

    var geminiRepository: any GeminiRepositoryProtocol {
        useMock ? MockGeminiRepository() : MockGeminiRepository()
        // 本実装後: useMock ? MockGeminiRepository() : GeminiRepository()
    }

    var imagenRepository: any ImagenRepositoryProtocol {
        useMock ? MockImagenRepository() : MockImagenRepository()
        // 本実装後: useMock ? MockImagenRepository() : ImagenRepository()
    }
}

// MARK: - Preview Support

extension DIContainer {
    static var preview: DIContainer {
        DIContainer(useMock: true)
    }
}
