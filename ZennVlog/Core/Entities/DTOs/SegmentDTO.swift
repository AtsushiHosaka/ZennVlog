import Foundation

struct SegmentDTO: Codable, Sendable {
    let order: Int
    let startSec: Double
    let endSec: Double
    let description: String
}
