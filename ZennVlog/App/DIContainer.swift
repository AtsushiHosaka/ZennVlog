import Foundation

@MainActor
final class DIContainer {

    // MARK: - Singleton

    static let shared = DIContainer()

    // MARK: - Properties

    let useMock: Bool

    struct LiveDependencies {
        let projectRepository: any ProjectRepositoryProtocol
        let templateRepository: any TemplateRepositoryProtocol
        let bgmRepository: any BGMRepositoryProtocol
        let geminiRepository: any GeminiRepositoryProtocol
        let imagenRepository: any ImagenRepositoryProtocol
        let photoLibraryService: any PhotoLibraryServiceProtocol
        let activityControllerService: any ActivityControllerServiceProtocol
    }

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

    init(
        useMock: Bool = false,
        liveDependencies: LiveDependencies? = nil
    ) {
        #if DEBUG
        self.useMock = ProcessInfo.processInfo.environment["USE_MOCK"] == "true" || useMock
        #else
        self.useMock = false
        #endif

        if self.useMock {
            self.projectRepository = MockProjectRepository()
            self.templateRepository = MockTemplateRepository()
            self.bgmRepository = MockBGMRepository()
            self.geminiRepository = MockGeminiRepository()
            self.imagenRepository = MockImagenRepository()
            self.photoLibraryService = MockPhotoLibraryService()
            self.activityControllerService = MockActivityControllerService()
        } else if let liveDependencies {
            self.projectRepository = liveDependencies.projectRepository
            self.templateRepository = liveDependencies.templateRepository
            self.bgmRepository = liveDependencies.bgmRepository
            self.geminiRepository = liveDependencies.geminiRepository
            self.imagenRepository = liveDependencies.imagenRepository
            self.photoLibraryService = liveDependencies.photoLibraryService
            self.activityControllerService = liveDependencies.activityControllerService
        } else {
            let googleServiceConfig = GoogleServiceConfigLoader.load()
            let httpClient = HTTPClient()
            let firestoreDataSource = FirestoreRESTDataSource(
                config: googleServiceConfig,
                httpClient: httpClient
            )
            let storageDataSource = StorageRESTDataSource(
                config: googleServiceConfig,
                httpClient: httpClient
            )
            let geminiDataSource = GeminiRESTDataSource(
                apiKey: SecretsManager.geminiAPIKey,
                httpClient: httpClient
            )

            self.projectRepository = SwiftDataProjectRepository()
            self.templateRepository = FirestoreTemplateRepository(
                dataSource: firestoreDataSource
            )
            self.bgmRepository = FirestoreBGMRepository(
                dataSource: firestoreDataSource,
                storageDataSource: storageDataSource
            )
            self.geminiRepository = LiveGeminiRepository(
                dataSource: geminiDataSource
            )
            self.imagenRepository = LiveImagenRepository(
                dataSource: geminiDataSource
            )
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
