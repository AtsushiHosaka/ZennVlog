import Foundation

protocol BGMRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [BGMTrack]
    func fetch(by id: String) async throws -> BGMTrack?
    func downloadURL(for track: BGMTrack) async throws -> URL
}
