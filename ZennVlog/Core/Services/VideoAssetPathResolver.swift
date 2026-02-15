import Foundation

enum VideoAssetPathResolver {
    nonisolated static func resolveLocalURL(from value: String?) -> URL? {
        let fileManager = FileManager()
        guard let value else { return nil }
        let raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        if let parsed = URL(string: raw), parsed.isFileURL {
            let standardized = parsed.standardizedFileURL
            guard fileManager.fileExists(atPath: standardized.path) else { return nil }
            return standardized
        }

        if raw.hasPrefix("/") {
            let url = URL(fileURLWithPath: raw).standardizedFileURL
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            return url
        }

        let fileName = URL(fileURLWithPath: raw).lastPathComponent
        for directory in candidateDirectories(fileManager: fileManager) {
            let direct = directory.appendingPathComponent(raw).standardizedFileURL
            if fileManager.fileExists(atPath: direct.path) {
                return direct
            }

            let byName = directory.appendingPathComponent(fileName).standardizedFileURL
            if fileManager.fileExists(atPath: byName.path) {
                return byName
            }
        }

        return nil
    }

    nonisolated static func applicationVideoAssetsDirectory() -> URL? {
        let fileManager = FileManager()
        guard let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }

        return appSupport
            .appendingPathComponent("ZennVlog", isDirectory: true)
            .appendingPathComponent("VideoAssets", isDirectory: true)
            .standardizedFileURL
    }

    nonisolated static func isManagedVideoURL(_ url: URL) -> Bool {
        guard let base = applicationVideoAssetsDirectory() else { return false }
        let candidate = url.standardizedFileURL.path
        let basePath = base.standardizedFileURL.path
        return candidate.hasPrefix(basePath)
    }

    nonisolated private static func candidateDirectories(fileManager: FileManager) -> [URL] {
        var directories: [URL] = []

        if let managedBase = applicationVideoAssetsDirectory() {
            directories.append(managedBase)
        }

        if let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            directories.append(docs)
        }

        if let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            directories.append(caches)
        }

        directories.append(fileManager.temporaryDirectory)
        return directories
    }
}
