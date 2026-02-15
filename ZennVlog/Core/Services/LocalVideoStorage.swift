import Foundation
import OSLog

final class LocalVideoStorage: Sendable {
    private let fileManager: FileManager
    private let logger = Logger(subsystem: "ZennVlog", category: "LocalVideoStorage")

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func persistVideo(sourceURL: URL, projectId: UUID, assetId: UUID) throws -> URL {
        let source = sourceURL.standardizedFileURL
        guard fileManager.fileExists(atPath: source.path) else {
            throw LocalVideoStorageError.sourceNotFound(source.path)
        }

        let projectDirectory = try ensureProjectDirectory(projectId: projectId)
        let fileExtension = source.pathExtension.isEmpty ? "mov" : source.pathExtension
        let destination = projectDirectory
            .appendingPathComponent(assetId.uuidString)
            .appendingPathExtension(fileExtension)
            .standardizedFileURL

        if source.path != destination.path {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)
        }

        logger.info("Persisted video. source=\(source.path, privacy: .public) destination=\(destination.path, privacy: .public)")
        return destination
    }

    func removeManagedVideo(atPath path: String) throws {
        guard let url = VideoAssetPathResolver.resolveLocalURL(from: path) else { return }
        guard VideoAssetPathResolver.isManagedVideoURL(url) else { return }
        guard fileManager.fileExists(atPath: url.path) else { return }

        try fileManager.removeItem(at: url)
        logger.info("Removed managed video. path=\(url.path, privacy: .public)")
    }

    private func ensureProjectDirectory(projectId: UUID) throws -> URL {
        guard let baseDirectory = VideoAssetPathResolver.applicationVideoAssetsDirectory() else {
            throw LocalVideoStorageError.applicationSupportNotFound
        }

        let projectDirectory = baseDirectory.appendingPathComponent(projectId.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        return projectDirectory.standardizedFileURL
    }
}

enum LocalVideoStorageError: LocalizedError {
    case applicationSupportNotFound
    case sourceNotFound(String)

    var errorDescription: String? {
        switch self {
        case .applicationSupportNotFound:
            return "動画保存先ディレクトリを作成できませんでした"
        case .sourceNotFound(let path):
            return "保存元の動画ファイルが見つかりません: \(path)"
        }
    }
}
