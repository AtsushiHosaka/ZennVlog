import Foundation

struct GeminiChatResponse: Sendable {
    let text: String
    let suggestedTemplates: [TemplateDTO]
}
