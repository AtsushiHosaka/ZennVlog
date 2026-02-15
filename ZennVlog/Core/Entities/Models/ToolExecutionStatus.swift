import Foundation

/// ツール実行の状態
enum ToolExecutionState: String, Sendable {
    case executing = "実行中"
    case completed = "完了"
    case failed = "失敗"
}

/// ツール実行状態
struct ToolExecutionStatus: Identifiable, Sendable {
    let id: UUID
    let toolName: String
    let state: ToolExecutionState
    let result: String?
    let timestamp: Date

    init(
        id: UUID = UUID(),
        toolName: String,
        state: ToolExecutionState = .executing,
        result: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.toolName = toolName
        self.state = state
        self.result = result
        self.timestamp = timestamp
    }

    var displayMessage: String {
        switch toolName {
        case "templateSearch":
            return state == .executing ? "テンプレートを検索中..." : "テンプレート検索完了"
        case "videoSummary", "videoAnalysis":
            return state == .executing ? "動画を分析中..." : "動画分析完了"
        case "generateCustomTemplate":
            return state == .executing ? "オリジナルテンプレートを作成中..." : "テンプレート作成完了"
        default:
            return state == .executing ? "\(toolName)を実行中..." : "\(toolName)完了"
        }
    }
}
