import Foundation
import SwiftData

@Model
final class Segment {
    var id: UUID
    var order: Int
    var startSeconds: Double
    var endSeconds: Double
    var segmentDescription: String

    init(
        id: UUID = UUID(),
        order: Int = 0,
        startSeconds: Double = 0,
        endSeconds: Double = 0,
        segmentDescription: String = ""
    ) {
        self.id = id
        self.order = order
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.segmentDescription = segmentDescription
    }
}
