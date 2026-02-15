import Foundation
import SwiftData

enum ProjectStatus: String, Codable {
    case chatting
    case recording
    case editing
    case completed
}

@Model
final class Project {
    var id: UUID
    var name: String
    var theme: String
    var projectDescription: String
    var template: Template?
    @Relationship(deleteRule: .cascade) var videoAssets: [VideoAsset]
    @Relationship(deleteRule: .cascade) var videoAnalysisSessions: [VideoAnalysisSession]
    @Relationship(deleteRule: .cascade) var subtitles: [Subtitle]
    @Relationship(deleteRule: .cascade) var chatHistory: [ChatMessage]
    var selectedBGMId: String?
    var bgmVolume: Float
    var status: ProjectStatus
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        theme: String = "",
        projectDescription: String = "",
        template: Template? = nil,
        videoAssets: [VideoAsset] = [],
        videoAnalysisSessions: [VideoAnalysisSession] = [],
        subtitles: [Subtitle] = [],
        chatHistory: [ChatMessage] = [],
        selectedBGMId: String? = nil,
        bgmVolume: Float = 0.3,
        status: ProjectStatus = .chatting,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.theme = theme
        self.projectDescription = projectDescription
        self.template = template
        self.videoAssets = videoAssets
        self.videoAnalysisSessions = videoAnalysisSessions
        self.subtitles = subtitles
        self.chatHistory = chatHistory
        self.selectedBGMId = selectedBGMId
        self.bgmVolume = bgmVolume
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
