import Foundation

@MainActor
final class DIContainer {

    // MARK: - Singleton

    static let shared = DIContainer()

    // MARK: - Properties

    let useMock: Bool

    // MARK: - Cached Repositories

    let projectRepository: any ProjectRepositoryProtocol
    let templateRepository: any TemplateRepositoryProtocol
    let bgmRepository: any BGMRepositoryProtocol
    let geminiRepository: any GeminiRepositoryProtocol
    let imagenRepository: any ImagenRepositoryProtocol

    // MARK: - Services

    let photoLibraryService: any PhotoLibraryServiceProtocol
    let activityControllerService: any ActivityControllerServiceProtocol

    // MARK: - Init

    init(useMock: Bool = false) {
        #if DEBUG
        self.useMock = ProcessInfo.processInfo.environment["USE_MOCK"] == "true" || useMock
        #else
        self.useMock = false
        #endif

        self.projectRepository = MockProjectRepository()
        self.templateRepository = MockTemplateRepository()
        self.bgmRepository = MockBGMRepository()
        self.geminiRepository = MockGeminiRepository()
        self.imagenRepository = MockImagenRepository()

        if self.useMock {
            self.photoLibraryService = MockPhotoLibraryService()
            self.activityControllerService = MockActivityControllerService()
        } else {
            self.photoLibraryService = RealPhotoLibraryService()
            self.activityControllerService = RealActivityControllerService()
        }
    }
}

// MARK: - Preview Support

extension DIContainer {
    static var preview: DIContainer {
        DIContainer(useMock: true)
    }
}
