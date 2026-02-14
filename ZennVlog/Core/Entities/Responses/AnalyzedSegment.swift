import Foundation

struct AnalyzedSegment: Sendable {
    let startSeconds: Double
    let endSeconds: Double
    let description: String
    let confidence: Double?
    let visualLabels: [String]?

    init(
        startSeconds: Double,
        endSeconds: Double,
        description: String,
        confidence: Double? = nil,
        visualLabels: [String]? = nil
    ) {
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.description = description
        self.confidence = confidence
        self.visualLabels = visualLabels
    }
}
