import Foundation

struct GeminiChatResponse: Sendable {
    let text: String
    let suggestedTemplates: [TemplateDTO]
    let quickReplies: [String]
    let analyzedVideoResult: VideoAnalysisResult?

    init(
        text: String,
        suggestedTemplates: [TemplateDTO],
        quickReplies: [String],
        analyzedVideoResult: VideoAnalysisResult? = nil
    ) {
        self.text = text
        self.suggestedTemplates = suggestedTemplates
        self.quickReplies = quickReplies
        self.analyzedVideoResult = analyzedVideoResult
    }
}
