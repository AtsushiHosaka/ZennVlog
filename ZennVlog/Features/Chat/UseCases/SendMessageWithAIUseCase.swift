import Foundation

@MainActor
final class SendMessageWithAIUseCase {

    // MARK: - Properties

    private let repository: GeminiRepositoryProtocol
    private let templateRepository: TemplateRepositoryProtocol
    private let maxIterations = 5

    // MARK: - Init

    init(
        repository: GeminiRepositoryProtocol,
        templateRepository: TemplateRepositoryProtocol
    ) {
        self.repository = repository
        self.templateRepository = templateRepository
    }

    // MARK: - Execute

    func execute(
        message: String,
        history: [ChatMessageDTO],
        attachedVideoURL: URL? = nil,
        projectId: UUID? = nil,
        chatMode: ChatMode = .templateSelection,
        onToolExecution: ((ToolExecutionStatus) -> Void)? = nil
    ) async throws -> GeminiChatResponse {
        var contents = buildContents(
            from: history,
            newMessage: message,
            attachedVideoURL: attachedVideoURL,
            projectId: projectId
        )
        var foundTemplates: [TemplateDTO] = []
        var analyzedVideoResult: VideoAnalysisResult?

        let instruction = chatMode == .customCreation
            ? customCreationSystemInstruction : systemInstruction
        let tools = chatMode == .customCreation
            ? customCreationToolDeclarations : toolDeclarations

        for _ in 0..<maxIterations {
            let turnResponse = try await repository.sendTurn(
                systemInstruction: instruction,
                contents: contents,
                tools: tools
            )

            switch turnResponse {
            case .text(let jsonText):
                let response = try decodeChatResponse(from: jsonText)
                let templates = foundTemplates.isEmpty
                    ? [response.suggestedTemplate].compactMap { $0 }
                    : foundTemplates
                return GeminiChatResponse(
                    text: response.text,
                    suggestedTemplates: templates,
                    quickReplies: response.quickReplies ?? [],
                    analyzedVideoResult: analyzedVideoResult
                )

            case .functionCall(let name, let args, let rawPart):
                onToolExecution?(ToolExecutionStatus(toolName: name, state: .executing))

                let result: String
                switch name {
                case "templateSearch":
                    let (resultText, templates) = try await executeTemplateSearch(args: args)
                    result = resultText
                    foundTemplates = templates
                case "videoSummary", "videoAnalysis":
                    let (resultText, analysisResult) = try await executeVideoSummary(
                        args: args,
                        attachedVideoURL: attachedVideoURL
                    )
                    result = resultText
                    analyzedVideoResult = analysisResult
                case "generateCustomTemplate":
                    let resultTemplate = executeGenerateCustomTemplate(args: args)
                    result = encodeTemplateAsJSON(resultTemplate)
                    foundTemplates = [resultTemplate]
                default:
                    result = "{\"error\": \"Unknown tool: \(name)\"}"
                }

                onToolExecution?(ToolExecutionStatus(toolName: name, state: .completed))

                // Append the model's function call with raw part (preserves thought_signature)
                contents.append([
                    "role": "model",
                    "parts": [rawPart]
                ])

                // Parse result JSON string into an object for the API
                let responseObject: Any
                if let resultData = result.data(using: .utf8),
                   let parsed = try? JSONSerialization.jsonObject(with: resultData) {
                    responseObject = parsed
                } else {
                    responseObject = ["result": result]
                }

                // Append the function result
                contents.append([
                    "role": "function",
                    "parts": [["functionResponse": ["name": name, "response": responseObject]]]
                ])
            }
        }

        throw GeminiRepositoryError.requestFailed(
            underlying: NSError(domain: "SendMessageWithAIUseCase", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Function calling loop exceeded maximum iterations"
            ])
        )
    }

    // MARK: - Private Methods

    private func buildContents(
        from history: [ChatMessageDTO],
        newMessage: String,
        attachedVideoURL: URL?,
        projectId: UUID?
    ) -> [[String: Any]] {
        var contents: [[String: Any]] = history.map { item in
            [
                "role": item.role == .user ? "user" : "model",
                "parts": [["text": item.content]]
            ]
        }
        var parts: [[String: Any]] = [["text": newMessage]]
        if let projectId {
            parts.append(["text": "Project ID: \(projectId.uuidString)"])
        }
        if let attachedVideoURL {
            parts.append(["text": "Attached video URL: \(attachedVideoURL.absoluteString)"])
        }
        contents.append([
            "role": "user",
            "parts": parts
        ])
        return contents
    }

    private func executeTemplateSearch(args: [String: String]) async throws -> (String, [TemplateDTO]) {
        let query = args["query"] ?? ""
        let category = args["category"]

        let allTemplates = try await templateRepository.fetchAll()
        let filtered = allTemplates.filter { template in
            let matchesQuery = query.isEmpty ||
                template.name.localizedCaseInsensitiveContains(query) ||
                template.description.localizedCaseInsensitiveContains(query) ||
                template.explanation.localizedCaseInsensitiveContains(query)
            let matchesCategory = category == nil ||
                template.name.localizedCaseInsensitiveContains(category!) ||
                template.description.localizedCaseInsensitiveContains(category!)
            return matchesQuery || matchesCategory
        }

        let results = Array(filtered.isEmpty ? allTemplates.prefix(3) : filtered.prefix(3))

        let templateInfos = results.map { t in
            ["id": t.id, "name": t.name, "description": t.description]
        }

        guard let data = try? JSONSerialization.data(withJSONObject: ["templates": templateInfos]),
              let json = String(data: data, encoding: .utf8) else {
            return ("{\"templates\": []}", [])
        }
        return (json, results)
    }

    private func executeVideoSummary(
        args: [String: String],
        attachedVideoURL: URL?
    ) async throws -> (String, VideoAnalysisResult) {
        let url: URL
        if let urlString = args["videoURL"] ?? args["videoUrl"],
           let parsed = URL(string: urlString) {
            url = parsed
        } else if let attachedVideoURL {
            url = attachedVideoURL
        } else {
            let message = "{\"error\": \"Missing video URL\"}"
            return (
                message,
                VideoAnalysisResult(segments: [])
            )
        }

        let result = try await repository.analyzeVideo(url: url)
        let segments = result.segments.map { segment in
            [
                "startSeconds": segment.startSeconds,
                "endSeconds": segment.endSeconds,
                "description": segment.description,
                "confidence": segment.confidence ?? 0
            ] as [String: Any]
        }

        guard let data = try? JSONSerialization.data(
            withJSONObject: [
                "sourceVideoURL": url.absoluteString,
                "segments": segments
            ]
        ),
        let json = String(data: data, encoding: .utf8) else {
            return ("{\"segments\": []}", result)
        }
        return (json, result)
    }

    private func executeGenerateCustomTemplate(args: [String: String]) -> TemplateDTO {
        let name = args["name"] ?? "カスタムVlog"
        let description = args["description"] ?? ""
        let explanation = args["explanation"] ?? ""
        let totalDurationString = args["totalDuration"] ?? "60"
        let totalDuration = Double(totalDurationString) ?? 60.0

        // segments JSON のパース試行
        if let segmentsJSON = args["segments"],
           let data = segmentsJSON.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           !parsed.isEmpty {
            let segments = parsed.enumerated().map { index, dict in
                SegmentDTO(
                    order: (dict["order"] as? Int) ?? index,
                    startSec: (dict["startSec"] as? Double) ?? (dict["startSec"] as? Int).map(Double.init) ?? 0,
                    endSec: (dict["endSec"] as? Double) ?? (dict["endSec"] as? Int).map(Double.init) ?? 0,
                    description: (dict["description"] as? String) ?? "シーン\(index + 1)"
                )
            }
            return TemplateDTO(
                id: "custom-\(UUID().uuidString)",
                name: name,
                description: description,
                referenceVideoUrl: "",
                explanation: explanation,
                segments: segments
            )
        }

        // フォールバック: sceneCount と totalDuration から均等分割
        let sceneCountString = args["sceneCount"] ?? "3"
        let sceneCount = max(Int(sceneCountString) ?? 3, 1)
        let segmentDuration = totalDuration / Double(sceneCount)
        let segments = (0..<sceneCount).map { i in
            SegmentDTO(
                order: i,
                startSec: Double(i) * segmentDuration,
                endSec: Double(i + 1) * segmentDuration,
                description: "シーン\(i + 1)"
            )
        }
        return TemplateDTO(
            id: "custom-\(UUID().uuidString)",
            name: name,
            description: description,
            referenceVideoUrl: "",
            explanation: explanation,
            segments: segments
        )
    }

    private func encodeTemplateAsJSON(_ template: TemplateDTO) -> String {
        let segmentsArray = template.segments.map { segment in
            [
                "order": segment.order,
                "startSec": segment.startSec,
                "endSec": segment.endSec,
                "description": segment.description
            ] as [String: Any]
        }
        let dict: [String: Any] = [
            "id": template.id,
            "name": template.name,
            "description": template.description,
            "explanation": template.explanation,
            "segments": segmentsArray
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"error\": \"Failed to encode template\"}"
        }
        return json
    }

    private func decodeChatResponse(from text: String) throws -> ChatResponsePayload {
        // Function Calling 併用時は responseMimeType が使えないため、
        // Gemini がプレーンテキストや Markdown コードブロックで返す場合がある。

        let jsonString = extractJSON(from: text)

        if let data = jsonString.data(using: .utf8),
           let payload = try? JSONDecoder().decode(ChatResponsePayload.self, from: data) {
            return payload
        }

        // JSONパース失敗時: textフィールドだけ手動抽出を試みる
        if let data = jsonString.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let extractedText = dict["text"] as? String {
            return ChatResponsePayload(
                text: extractedText,
                suggestedTemplate: nil,
                quickReplies: dict["quickReplies"] as? [String]
            )
        }

        // それでもダメならプレーンテキスト（JSONっぽい部分を除去）
        let cleanText = stripJSONBlocks(from: text)
        return ChatResponsePayload(text: cleanText, suggestedTemplate: nil, quickReplies: nil)
    }

    private func extractJSON(from text: String) -> String {
        // ```json ... ``` または ``` ... ``` からJSONを抽出
        let codeBlockPattern = /```(?:json)?\s*\n([\s\S]*?)\n\s*```/
        if let match = text.firstMatch(of: codeBlockPattern) {
            return String(match.1)
        }
        return text
    }

    private func stripJSONBlocks(from text: String) -> String {
        // コードブロックやJSON文字列を除去して読めるテキストだけ残す
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // JSONオブジェクトっぽい文字列ならフォールバックメッセージ
        if cleaned.hasPrefix("{") && cleaned.hasSuffix("}") {
            return "テンプレートの準備ができました。"
        }
        return cleaned
    }

    // MARK: - Constants

    private let systemInstruction = """
    You are a friendly vlog planning assistant. Help users plan their vlogs by understanding their theme and preferences.
    Always respond in Japanese.

    You have access to the following tools:
    - templateSearch: Search for vlog templates matching user preferences
    - videoSummary: Analyze attached videos to extract segments

    When the user describes what kind of vlog they want to create, use templateSearch to find matching templates.
    When analyzing videos, use videoSummary.

    After using tools, summarize the result conversationally. Do NOT echo back raw JSON or technical data.

    IMPORTANT: Always return your response as JSON in this exact schema:
    {
      "text": "string",
      "quickReplies": ["string"] | [],
      "suggestedTemplate": { ... } | null
    }

    Rules:
    - "text" must contain ONLY the conversational message in Japanese. NEVER include raw JSON, code blocks, or technical data.
    - quickReplies: Provide 2-4 short reply options the user can tap instead of typing.
    - Examples: ["はい", "いいえ"], ["日常", "旅行", "グルメ", "趣味"]
    - Set quickReplies to [] when the user should type freely.
    """

    private let toolDeclarations: [[String: Any]] = [
        [
            "name": "templateSearch",
            "description": "Search for vlog templates matching user preferences. Use this when the user describes what kind of vlog they want.",
            "parameters": [
                "type": "OBJECT",
                "properties": [
                    "query": [
                        "type": "STRING",
                        "description": "Search query describing the desired vlog style or theme"
                    ],
                    "category": [
                        "type": "STRING",
                        "description": "Optional category filter (e.g., daily, travel, cooking)"
                    ]
                ],
                "required": ["query"]
            ]
        ],
        [
            "name": "videoSummary",
            "description": "Analyze an attached video to extract scene segments for vlog editing.",
            "parameters": [
                "type": "OBJECT",
                "properties": [
                    "videoURL": [
                        "type": "STRING",
                        "description": "URL of the video to analyze"
                    ]
                ],
                "required": ["videoURL"]
            ]
        ]
    ]

    // MARK: - Custom Creation Constants

    private let customCreationSystemInstruction = """
    You are a friendly vlog planning assistant that helps users create original, \
    custom video templates from scratch through conversation.
    Always respond in Japanese.

    Gather the following information through natural conversation:
    1. Theme/topic (何を撮影するか)
    2. Total video length (動画の長さ)
    3. Number of scenes (シーンの数)
    4. Content for each scene (各シーンの内容)

    Guidelines:
    - Ask ONE question at a time
    - Start with theme → length → scene count → scene details
    - When enough info is gathered, call generateCustomTemplate
    - After generating, ask if the user is satisfied. Do NOT echo back the template JSON. Summarize it conversationally instead.
    - If not satisfied, discuss modifications and regenerate

    IMPORTANT: Always return your response as JSON in this exact schema:
    {
      "text": "string",
      "quickReplies": ["string"] | [],
      "suggestedTemplate": { ... } | null
    }

    Rules:
    - "text" must contain ONLY the conversational message in Japanese. NEVER include raw JSON, code blocks, or technical data.
    - quickReplies: Provide 2-4 short reply options the user can tap instead of typing.
    - For theme: ["カフェ巡り", "旅行", "日常", "料理"]
    - For length: ["30秒", "1分", "3分", "5分"]
    - For scene count: ["3", "5", "7", "おまかせ"]
    - For confirmation: ["はい", "修正したい"]
    - Set quickReplies to [] when the user should type freely.
    """

    private let customCreationToolDeclarations: [[String: Any]] = [
        [
            "name": "generateCustomTemplate",
            "description": "Generate a custom vlog template based on user preferences gathered through conversation.",
            "parameters": [
                "type": "OBJECT",
                "properties": [
                    "name": [
                        "type": "STRING",
                        "description": "テンプレート名"
                    ],
                    "description": [
                        "type": "STRING",
                        "description": "テンプレートの説明"
                    ],
                    "explanation": [
                        "type": "STRING",
                        "description": "構成の詳細・撮影ヒント"
                    ],
                    "totalDuration": [
                        "type": "STRING",
                        "description": "総尺（秒数）"
                    ],
                    "sceneCount": [
                        "type": "STRING",
                        "description": "シーン数"
                    ],
                    "segments": [
                        "type": "STRING",
                        "description": "JSON配列文字列 [{\"order\":0,\"startSec\":0,\"endSec\":10,\"description\":\"オープニング\"}, ...]"
                    ]
                ],
                "required": ["name", "description", "totalDuration", "segments"]
            ]
        ],
        [
            "name": "videoSummary",
            "description": "Analyze an attached video to extract scene segments for vlog editing.",
            "parameters": [
                "type": "OBJECT",
                "properties": [
                    "videoURL": [
                        "type": "STRING",
                        "description": "URL of the video to analyze"
                    ]
                ],
                "required": ["videoURL"]
            ]
        ]
    ]
}

private struct ChatResponsePayload: Decodable {
    let text: String
    let suggestedTemplate: TemplateDTO?
    let quickReplies: [String]?
}
