import Foundation
import SwiftData

@Model
final class VideoAnalysisScene {
    var id: UUID
    var startSeconds: Double
    var endSeconds: Double
    var sceneDescription: String
    var confidence: Double?
    var visualLabels: [String]

    init(
        id: UUID = UUID(),
        startSeconds: Double,
        endSeconds: Double,
        sceneDescription: String,
        confidence: Double? = nil,
        visualLabels: [String] = []
    ) {
        self.id = id
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.sceneDescription = sceneDescription
        self.confidence = confidence
        self.visualLabels = visualLabels
    }
}
