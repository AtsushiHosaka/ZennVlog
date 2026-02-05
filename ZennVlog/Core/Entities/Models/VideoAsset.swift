import Foundation
import SwiftData

@Model
final class VideoAsset {
    var id: UUID
    var segmentOrder: Int?
    var localFileURL: String
    var duration: Double
    var trimStartSeconds: Double = 0.0
    var createdAt: Date

    init(
        id: UUID = UUID(),
        segmentOrder: Int? = nil,
        localFileURL: String = "",
        duration: Double = 0,
        trimStartSeconds: Double = 0.0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.segmentOrder = segmentOrder
        self.localFileURL = localFileURL
        self.duration = duration
        self.trimStartSeconds = trimStartSeconds
        self.createdAt = createdAt
    }
}
