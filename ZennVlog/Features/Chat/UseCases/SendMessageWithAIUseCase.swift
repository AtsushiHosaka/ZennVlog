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
        onToolExecution: ((ToolExecutionStatus) -> Void)? = nil
    ) async throws -> GeminiChatResponse {
        var contents = buildContents(from: history, newMessage: message)
        var foundTemplates: [TemplateDTO] = []

        for _ in 0..<maxIterations {
            let turnResponse = try await repository.sendTurn(
                systemInstruction: systemInstruction,
                contents: contents,
                tools: toolDeclarations
            )

            switch turnResponse {
            case .text(let jsonText):
                let response = try decodeChatResponse(from: jsonText)
                let templates = foundTemplates.isEmpty
                    ? [response.suggestedTemplate].compactMap { $0 }
                    : foundTemplates
                return GeminiChatResponse(
                    text: response.text,
                    suggestedTemplates: templates
                )

            case .functionCall(let name, let args, let rawPart):
                onToolExecution?(ToolExecutionStatus(toolName: name, state: .executing))

                let result: String
                switch name {
                case "templateSearch":
                    let (resultText, templates) = try await executeTemplateSearch(args: args)
                    result = resultText
                    foundTemplates = templates
                case "videoAnalysis":
                    result = try await executeVideoAnalysis(args: args)
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

    private func buildContents(from history: [ChatMessageDTO], newMessage: String) -> [[String: Any]] {
        var contents: [[String: Any]] = history.map { item in
            [
                "role": item.role == .user ? "user" : "model",
                "parts": [["text": item.content]]
            ]
        }
        contents.append([
            "role": "user",
            "parts": [["text": newMessage]]
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

    private func executeVideoAnalysis(args: [String: String]) async throws -> String {
        guard let urlString = args["videoURL"],
              let url = URL(string: urlString) else {
            return "{\"error\": \"Invalid video URL\"}"
        }

        let result = try await repository.analyzeVideo(url: url)
        let segments = result.segments.map { segment in
            [
                "startSeconds": segment.startSeconds,
                "endSeconds": segment.endSeconds,
                "description": segment.description
            ] as [String: Any]
        }

        guard let data = try? JSONSerialization.data(withJSONObject: ["segments": segments]),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"segments\": []}"
        }
        return json
    }

    private func decodeChatResponse(from json: String) throws -> ChatResponsePayload {
        guard let data = json.data(using: .utf8) else {
            throw GeminiRepositoryError.responseParseFailed(
                underlying: NSError(domain: "SendMessageWithAIUseCase", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid UTF-8 JSON"
                ])
            )
        }
        do {
            return try JSONDecoder().decode(ChatResponsePayload.self, from: data)
        } catch {
            throw GeminiRepositoryError.responseParseFailed(underlying: error)
        }
    }

    // MARK: - Constants

    private let systemInstruction = """
    You are a friendly vlog planning assistant. Help users plan their vlogs by understanding their theme and preferences.

    You have access to the following tools:
    - templateSearch: Search for vlog templates matching user preferences
    - videoAnalysis: Analyze attached videos to extract segments

    When the user describes what kind of vlog they want to create, use templateSearch to find matching templates.
    When analyzing videos, use videoAnalysis.

    After using tools, incorporate the results into your response naturally.

    Return your final response as JSON in this schema:
    {
      "text": "string",
      "suggestedTemplate": {
        "id": "string",
        "name": "string",
        "description": "string",
        "referenceVideoUrl": "string",
        "explanation": "string",
        "segments": [
          {
            "order": 0,
            "startSec": 0.0,
            "endSec": 5.0,
            "description": "string"
          }
        ]
      } | null
    }
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
            "name": "videoAnalysis",
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
}
