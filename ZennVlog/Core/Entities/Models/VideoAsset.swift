import Foundation
import SwiftData

@Model
final class VideoAsset {
    var id: UUID
    var segmentOrder: Int
    var localFileURL: String
    var duration: Double
    var createdAt: Date

    init(
        id: UUID = UUID(),
        segmentOrder: Int = 0,
        localFileURL: String = "",
        duration: Double = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.segmentOrder = segmentOrder
        self.localFileURL = localFileURL
        self.duration = duration
        self.createdAt = createdAt
    }
}
