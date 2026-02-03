import Foundation

struct BGMTrack: Identifiable, Codable, Sendable {
    let id: String
    let title: String
    let description: String
    let genre: String
    let duration: Int
    let storageUrl: String
    let tags: [String]
}
