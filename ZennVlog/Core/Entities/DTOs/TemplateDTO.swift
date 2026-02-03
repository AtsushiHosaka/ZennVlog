import Foundation

struct TemplateDTO: Identifiable, Codable, Sendable {
    let id: String
    let name: String
    let description: String
    let referenceVideoUrl: String
    let explanation: String
    let segments: [SegmentDTO]
}
