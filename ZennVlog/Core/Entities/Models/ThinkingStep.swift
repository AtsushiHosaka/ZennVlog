import Foundation

/// 思考プロセスのステップタイプ
enum ThinkingStepType: String, Codable, Sendable {
    case reasoning = "推論中"
    case analyzing = "分析中"
    case planning = "計画中"
    case concluding = "結論中"

    var iconName: String {
        switch self {
        case .reasoning: return "brain.head.profile"
        case .analyzing: return "magnifyingglass"
        case .planning: return "list.bullet.clipboard"
        case .concluding: return "checkmark.circle"
        }
    }
}

/// AIの思考プロセスステップ
struct ThinkingStep: Identifiable, Sendable {
    let id: UUID
    let type: ThinkingStepType
    let description: String
    let timestamp: Date

    init(
        id: UUID = UUID(),
        type: ThinkingStepType,
        description: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.description = description
        self.timestamp = timestamp
    }
}
