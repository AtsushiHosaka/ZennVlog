import Foundation

struct GeminiChatResponse: Sendable {
    let text: String
    let suggestedTemplate: TemplateDTO?
    let suggestedBGM: BGMTrack?
}
