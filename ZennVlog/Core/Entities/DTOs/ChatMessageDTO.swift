import Foundation

struct ChatMessageDTO: Sendable {
    let role: ChatRoleDTO
    let content: String
    let attachedVideoURL: String?
}

enum ChatRoleDTO: String, Sendable {
    case user
    case assistant
}
