import Foundation

struct RecoveryResult: Sendable, Equatable {
    let recoveredAssetIds: [UUID]
    let missingAssetIds: [UUID]
    let missingSegmentOrders: [Int]
    let messages: [String]
}

@MainActor
final class RecoverVideoAssetsUseCase {

    // MARK: - Properties

    private let repository: ProjectRepositoryProtocol
    private let photoLibraryService: PhotoLibraryServiceProtocol
    private let localVideoStorage: LocalVideoStorage

    // MARK: - Init

    init(
        repository: ProjectRepositoryProtocol,
        photoLibraryService: PhotoLibraryServiceProtocol,
        localVideoStorage: LocalVideoStorage
    ) {
        self.repository = repository
        self.photoLibraryService = photoLibraryService
        self.localVideoStorage = localVideoStorage
    }

    // MARK: - Execute

    func execute(project: Project) async -> RecoveryResult {
        var recoveredAssetIds = Set<UUID>()
        var missingAssetIds = Set<UUID>()
        var messages: [String] = []
        var hasProjectMutation = false

        for asset in project.videoAssets {
            if let resolvedURL = VideoAssetPathResolver.resolveLocalURL(from: asset.localFileURL) {
                let standardizedResolvedURL = resolvedURL.standardizedFileURL
                let standardizedPath = standardizedResolvedURL.path
                if asset.localFileURL != standardizedPath {
                    asset.localFileURL = standardizedPath
                    hasProjectMutation = true
                }

                if !VideoAssetPathResolver.isManagedVideoURL(standardizedResolvedURL) {
                    do {
                        let persistedURL = try localVideoStorage.persistVideo(
                            sourceURL: standardizedResolvedURL,
                            projectId: project.id,
                            assetId: asset.id
                        )
                        let persistedPath = persistedURL.standardizedFileURL.path
                        if asset.localFileURL != persistedPath {
                            asset.localFileURL = persistedPath
                            hasProjectMutation = true
                            recoveredAssetIds.insert(asset.id)
                            if let order = asset.segmentOrder {
                                messages.append("S\(order + 1) をローカル保存先へ復旧しました")
                            }
                        }
                    } catch {
                        if let order = asset.segmentOrder {
                            messages.append("S\(order + 1) の再配置に失敗しました")
                        }
                    }
                }
                continue
            }

            let trimmedIdentifier = asset.photoAssetIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let assetIdentifier = trimmedIdentifier, !assetIdentifier.isEmpty else {
                missingAssetIds.insert(asset.id)
                if let order = asset.segmentOrder {
                    messages.append("S\(order + 1) の元素材が見つかりません")
                }
                continue
            }

            do {
                let temporaryURL = try await photoLibraryService.exportVideoToTemporaryFile(
                    assetIdentifier: assetIdentifier
                )
                let persistedURL = try localVideoStorage.persistVideo(
                    sourceURL: temporaryURL,
                    projectId: project.id,
                    assetId: asset.id
                )
                let persistedPath = persistedURL.standardizedFileURL.path
                if asset.localFileURL != persistedPath {
                    asset.localFileURL = persistedPath
                    hasProjectMutation = true
                }
                recoveredAssetIds.insert(asset.id)
                if let order = asset.segmentOrder {
                    messages.append("S\(order + 1) をフォトライブラリから復旧しました")
                }
            } catch {
                missingAssetIds.insert(asset.id)
                if let order = asset.segmentOrder {
                    messages.append("S\(order + 1) を復旧できませんでした")
                }
            }
        }

        if hasProjectMutation {
            do {
                try await repository.save(project)
            } catch {
                messages.append("復旧内容の保存に失敗しました")
            }
        }

        let missingSegmentOrders = calculateMissingSegmentOrders(
            project: project,
            explicitMissingAssetIds: missingAssetIds
        )

        return RecoveryResult(
            recoveredAssetIds: recoveredAssetIds.sorted { $0.uuidString < $1.uuidString },
            missingAssetIds: missingAssetIds.sorted { $0.uuidString < $1.uuidString },
            missingSegmentOrders: missingSegmentOrders,
            messages: messages
        )
    }

    private func calculateMissingSegmentOrders(
        project: Project,
        explicitMissingAssetIds: Set<UUID>
    ) -> [Int] {
        let templateOrders = Set((project.template?.segments ?? []).map(\.order))
        guard !templateOrders.isEmpty else { return [] }

        let usableOrders = Set(
            project.videoAssets.compactMap { asset -> Int? in
                guard let order = asset.segmentOrder else { return nil }
                guard !explicitMissingAssetIds.contains(asset.id) else { return nil }
                guard VideoAssetPathResolver.resolveLocalURL(from: asset.localFileURL) != nil else { return nil }
                return order
            }
        )

        return Array(templateOrders.subtracting(usableOrders)).sorted()
    }
}
