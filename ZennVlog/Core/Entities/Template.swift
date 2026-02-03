import Foundation
import SwiftData

@Model
final class Template {
    var id: UUID
    var firestoreTemplateId: String?
    @Relationship(deleteRule: .cascade) var segments: [Segment]

    init(
        id: UUID = UUID(),
        firestoreTemplateId: String? = nil,
        segments: [Segment] = []
    ) {
        self.id = id
        self.firestoreTemplateId = firestoreTemplateId
        self.segments = segments
    }
}
