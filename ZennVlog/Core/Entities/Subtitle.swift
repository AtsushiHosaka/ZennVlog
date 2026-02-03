import Foundation
import SwiftData

@Model
final class Subtitle {
    var id: UUID
    var segmentOrder: Int
    var text: String

    init(
        id: UUID = UUID(),
        segmentOrder: Int = 0,
        text: String = ""
    ) {
        self.id = id
        self.segmentOrder = segmentOrder
        self.text = text
    }
}
