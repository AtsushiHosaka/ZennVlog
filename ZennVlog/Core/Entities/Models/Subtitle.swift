import Foundation
import SwiftData

@Model
final class Subtitle {
    var id: UUID
    var startSeconds: Double
    var endSeconds: Double
    var text: String
    var positionXRatio: Double
    var positionYRatio: Double

    init(
        id: UUID = UUID(),
        startSeconds: Double = 0,
        endSeconds: Double = 1,
        text: String = "",
        positionXRatio: Double = 0.5,
        positionYRatio: Double = 0.85
    ) {
        self.id = id
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.text = text
        self.positionXRatio = positionXRatio
        self.positionYRatio = positionYRatio
    }
}
