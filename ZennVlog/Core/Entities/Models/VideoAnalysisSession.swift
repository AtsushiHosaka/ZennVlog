import Foundation
import SwiftData

@Model
final class VideoAnalysisSession {
    var id: UUID
    var sourceVideoURL: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var scenes: [VideoAnalysisScene]

    init(
        id: UUID = UUID(),
        sourceVideoURL: String,
        createdAt: Date = Date(),
        scenes: [VideoAnalysisScene] = []
    ) {
        self.id = id
        self.sourceVideoURL = sourceVideoURL
        self.createdAt = createdAt
        self.scenes = scenes
    }
}
