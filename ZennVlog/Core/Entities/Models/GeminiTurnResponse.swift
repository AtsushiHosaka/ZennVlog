import Foundation

/// 1ターンのGemini応答（テキスト or ファンクションコール）
/// rawPartはGeminiレスポンスのパススルー用（thought_signature等を保持）
enum GeminiTurnResponse: @unchecked Sendable {
    case text(String)
    case functionCall(name: String, args: [String: String], rawPart: [String: Any])
}
