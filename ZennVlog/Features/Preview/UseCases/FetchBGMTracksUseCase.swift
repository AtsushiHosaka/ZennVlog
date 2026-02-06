import Foundation

@MainActor
final class FetchBGMTracksUseCase {

    // MARK: - Properties

    private let repository: BGMRepositoryProtocol

    // MARK: - Init

    init(repository: BGMRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute() async throws -> [BGMTrack] {
        try await repository.fetchAll()
    }
}
