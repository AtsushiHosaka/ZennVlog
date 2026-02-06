import Foundation

@MainActor
final class DownloadBGMUseCase {

    // MARK: - Properties

    private let repository: BGMRepositoryProtocol

    // MARK: - Init

    init(repository: BGMRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute(track: BGMTrack) async throws -> URL {
        try await repository.downloadURL(for: track)
    }
}
