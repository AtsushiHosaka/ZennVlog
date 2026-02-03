import Foundation
import SwiftData

enum ChatRole: String, Codable {
    case user
    case assistant
}

@Model
final class ChatMessage {
    var id: UUID
    var role: ChatRole
    var content: String
    var attachedVideoURL: String?
    var timestamp: Date

    init(
        id: UUID = UUID(),
        role: ChatRole = .user,
        content: String = "",
        attachedVideoURL: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.attachedVideoURL = attachedVideoURL
        self.timestamp = timestamp
    }
}
