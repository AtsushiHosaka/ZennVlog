#if DEBUG
import Foundation
import SwiftUI

enum PreviewFeatureDevelopment {
    static var launchMode: LaunchMode {
        LaunchMode.resolve(from: ProcessInfo.processInfo.environment)
    }

    @MainActor
    static func makePreviewDependencies() -> (container: DIContainer, viewModel: PreviewViewModel) {
        let templateDTO = makeTemplateDTO()
        let template = makeTemplateModel(from: templateDTO)
        let project = makeRecordedProject(using: template)
        let container = makeDevelopmentContainer(project: project, templateDTO: templateDTO)

        let viewModel = PreviewViewModel(
            project: project,
            exportVideoUseCase: ExportVideoUseCase(repository: container.projectRepository),
            fetchBGMTracksUseCase: FetchBGMTracksUseCase(repository: container.bgmRepository),
            saveSubtitleUseCase: SaveSubtitleUseCase(repository: container.projectRepository),
            deleteSubtitleUseCase: DeleteSubtitleUseCase(repository: container.projectRepository),
            saveBGMSettingsUseCase: SaveBGMSettingsUseCase(repository: container.projectRepository),
            downloadBGMUseCase: DownloadBGMUseCase(repository: container.bgmRepository),
            updateSubtitlePositionUseCase: UpdateSubtitlePositionUseCase(repository: container.projectRepository)
        )

        return (container, viewModel)
    }

    @MainActor
    static func makeRecordingDependencies() -> (container: DIContainer, viewModel: RecordingViewModel) {
        let templateDTO = makeTemplateDTO()
        let template = makeTemplateModel(from: templateDTO)
        let project = makeRecordingProject(using: template)
        let container = makeDevelopmentContainer(project: project, templateDTO: templateDTO)

        let viewModel = RecordingViewModel(
            project: project,
            saveVideoAssetUseCase: SaveVideoAssetUseCase(
                repository: container.projectRepository,
                localVideoStorage: container.localVideoStorage
            ),
            generateGuideImageUseCase: GenerateGuideImageUseCase(repository: container.imagenRepository),
            analyzeVideoUseCase: AnalyzeVideoUseCase(repository: container.geminiRepository),
            trimVideoUseCase: TrimVideoUseCase(),
            deleteVideoAssetUseCase: DeleteVideoAssetUseCase(
                repository: container.projectRepository,
                localVideoStorage: container.localVideoStorage
            ),
            photoLibraryService: container.photoLibraryService,
            localVideoStorage: container.localVideoStorage
        )

        return (container, viewModel)
    }

    private static func makeTemplateDTO() -> TemplateDTO {
        TemplateDTO(
            id: "dev-city-walk-vlog",
            name: "街歩きVlog",
            description: "出発から締めまでを短尺でつなぐ開発用テンプレート",
            referenceVideoUrl: "https://youtube.com/example/dev-city-walk",
            explanation: "移動、風景、食事、締めをバランス良く入れる構成",
            segments: [
                SegmentDTO(order: 0, startSec: 0, endSec: 4, description: "オープニング"),
                SegmentDTO(order: 1, startSec: 4, endSec: 12, description: "移動シーン"),
                SegmentDTO(order: 2, startSec: 12, endSec: 20, description: "街の風景"),
                SegmentDTO(order: 3, startSec: 20, endSec: 28, description: "食事シーン"),
                SegmentDTO(order: 4, startSec: 28, endSec: 32, description: "エンディング")
            ]
        )
    }

    private static func makeTemplateModel(from dto: TemplateDTO) -> Template {
        Template(
            firestoreTemplateId: dto.id,
            segments: dto.segments.map {
                Segment(
                    order: $0.order,
                    startSeconds: $0.startSec,
                    endSeconds: $0.endSec,
                    segmentDescription: $0.description
                )
            }
        )
    }

    private static func makeRecordedProject(using template: Template) -> Project {
        Project(
            name: "Preview機能開発用プロジェクト",
            theme: "街歩き",
            projectDescription: "RecordingViewで撮影済みを想定した開発用モック",
            template: template,
            videoAssets: [
                VideoAsset(segmentOrder: 0, localFileURL: "mock://recording/opening.mov", duration: 4.0),
                VideoAsset(segmentOrder: 1, localFileURL: "mock://recording/walk.mov", duration: 8.0, trimStartSeconds: 1.2),
                VideoAsset(segmentOrder: 2, localFileURL: "mock://recording/city.mov", duration: 8.0, trimStartSeconds: 0.8),
                VideoAsset(segmentOrder: 3, localFileURL: "mock://recording/food.mov", duration: 8.0),
                VideoAsset(segmentOrder: 4, localFileURL: "mock://recording/ending.mov", duration: 4.0),
                VideoAsset(segmentOrder: nil, localFileURL: "mock://recording/stock-extra.mov", duration: 10.0)
            ],
            subtitles: [
                Subtitle(startSeconds: 0, endSeconds: 3.2, text: "今日は街歩きVlogです"),
                Subtitle(startSeconds: 13, endSeconds: 18, text: "この通りの雰囲気が好き"),
                Subtitle(startSeconds: 28, endSeconds: 31, text: "また次の動画で会いましょう")
            ],
            selectedBGMId: "bgm-002",
            bgmVolume: 0.4,
            status: .editing,
            createdAt: Date().addingTimeInterval(-3600),
            updatedAt: Date().addingTimeInterval(-600)
        )
    }

    private static func makeRecordingProject(using template: Template) -> Project {
        Project(
            name: "Recording機能開発用プロジェクト",
            theme: "街歩き",
            projectDescription: "RecordingViewの開発用モック",
            template: template,
            videoAssets: [
                VideoAsset(segmentOrder: nil, localFileURL: "mock://recording/stock-extra.mov", duration: 10.0)
            ],
            status: .recording
        )
    }

    private static func makeDevelopmentContainer(project: Project, templateDTO: TemplateDTO) -> DIContainer {
        DIContainer(
            useMock: false,
            liveDependencies: .init(
                projectRepository: PreviewFeatureMockProjectRepository(seedProjects: [project]),
                templateRepository: PreviewFeatureMockTemplateRepository(templates: [templateDTO]),
                bgmRepository: MockBGMRepository(),
                geminiRepository: MockGeminiRepository(),
                imagenRepository: MockImagenRepository(),
                photoLibraryService: MockPhotoLibraryService(),
                activityControllerService: MockActivityControllerService(),
                localVideoStorage: LocalVideoStorage()
            )
        )
    }

    enum LaunchMode: String {
        case app
        case preview
        case recording

        static func resolve(from environment: [String: String]) -> LaunchMode {
            if let explicitMode = environment["DEV_LAUNCH_MODE"]?.lowercased() {
                switch explicitMode {
                case "preview", "previewview", "dev-preview":
                    return .preview
                case "recording", "recordingview", "dev-recording":
                    return .recording
                case "app", "normal", "main":
                    return .app
                default:
                    break
                }
            }

            // Backward compatibility:
            // DEV_PREVIEW_FEATURE=true  -> preview
            // DEV_PREVIEW_FEATURE=false -> app
            if let legacyFlag = environment["DEV_PREVIEW_FEATURE"]?.lowercased() {
                switch legacyFlag {
                case "1", "true", "yes", "on":
                    return .preview
                case "0", "false", "no", "off":
                    return .app
                default:
                    break
                }
            }

            // Default is normal app launch.
            return .app
        }
    }
}

@MainActor
private final class PreviewFeatureMockProjectRepository: ProjectRepositoryProtocol {
    private var projects: [UUID: Project]

    init(seedProjects: [Project]) {
        self.projects = Dictionary(uniqueKeysWithValues: seedProjects.map { ($0.id, $0) })
    }

    func fetchAll() async throws -> [Project] {
        projects.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    func fetch(by id: UUID) async throws -> Project? {
        projects[id]
    }

    func save(_ project: Project) async throws {
        project.updatedAt = Date()
        projects[project.id] = project
    }

    func delete(_ project: Project) async throws {
        projects.removeValue(forKey: project.id)
    }
}

private actor PreviewFeatureMockTemplateRepository: TemplateRepositoryProtocol {
    private let templates: [TemplateDTO]

    init(templates: [TemplateDTO]) {
        self.templates = templates
    }

    func fetchAll() async throws -> [TemplateDTO] {
        templates
    }

    func fetch(by id: String) async throws -> TemplateDTO? {
        templates.first { $0.id == id }
    }
}

@MainActor
struct PreviewFeatureDevelopmentRootView: View {
    @State private var previewViewModel: PreviewViewModel
    private let container: DIContainer

    init() {
        let dependencies = PreviewFeatureDevelopment.makePreviewDependencies()
        container = dependencies.container
        _previewViewModel = State(
            wrappedValue: dependencies.viewModel
        )
    }

    var body: some View {
        PreviewView(viewModel: previewViewModel, container: container)
    }
}

@MainActor
struct RecordingFeatureDevelopmentRootView: View {
    @State private var recordingViewModel: RecordingViewModel
    private let container: DIContainer

    init() {
        let dependencies = PreviewFeatureDevelopment.makeRecordingDependencies()
        container = dependencies.container
        _recordingViewModel = State(
            wrappedValue: dependencies.viewModel
        )
    }

    var body: some View {
        NavigationStack {
            RecordingView(viewModel: recordingViewModel, container: container)
        }
    }
}
#endif
