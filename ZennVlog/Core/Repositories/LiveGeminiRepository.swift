import Foundation

actor LiveGeminiRepository: GeminiRepositoryProtocol {

    // MARK: - Properties

    private let dataSource: any GeminiRESTDataSourceProtocol
    private let videoAnalysisDataSource: any VideoAnalysisJobDataSourceProtocol
    private let textModel: String

    // MARK: - Init

    init(
        dataSource: any GeminiRESTDataSourceProtocol = GeminiRESTDataSource(
            apiKey: SecretsManager.geminiAPIKey
        ),
        videoAnalysisDataSource: (any VideoAnalysisJobDataSourceProtocol)? = nil,
        textModel: String = SecretsManager.geminiTextModel,
        videoModel: String = SecretsManager.geminiVideoModel
    ) {
        self.dataSource = dataSource
        self.videoAnalysisDataSource = videoAnalysisDataSource ?? VideoAnalysisJobDataSource()
        self.textModel = textModel
        _ = videoModel
    }

    // MARK: - GeminiRepositoryProtocol

    func sendMessage(_ message: String, history: [ChatMessageDTO]) async throws -> GeminiChatResponse {
        do {
            let systemInstruction = """
            You are a vlog planning assistant.
            Return ONLY JSON in this schema:
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

            var messages = history.map { historyItem in
                GeminiMessage(
                    role: historyItem.role == .user ? "user" : "model",
                    text: historyItem.content
                )
            }
            messages.append(GeminiMessage(role: "user", text: message))

            let jsonText = try await dataSource.generateText(
                model: textModel,
                systemInstruction: systemInstruction,
                messages: messages
            )

            let payload = try decodeChatResponse(from: jsonText)

            return GeminiChatResponse(
                text: payload.text,
                suggestedTemplates: [payload.suggestedTemplate].compactMap { $0 },
                quickReplies: []
            )
        } catch let error as GeminiRepositoryError {
            throw error
        } catch {
            throw GeminiRepositoryError.requestFailed(underlying: error)
        }
    }

    func analyzeVideo(url: URL) async throws -> VideoAnalysisResult {
        do {
            let mimeType = mimeType(for: url)
            return try await videoAnalysisDataSource.analyzeVideo(
                url: url,
                mimeType: mimeType,
                projectId: nil
            )
        } catch let error as GeminiRepositoryError {
            throw error
        } catch {
            throw GeminiRepositoryError.videoAnalysisFailed(underlying: error)
        }
    }

    func sendTurn(
        systemInstruction: String,
        contents: [[String: Any]],
        tools: [[String: Any]]
    ) async throws -> GeminiTurnResponse {
        do {
            return try await dataSource.generateContentWithTools(
                model: textModel,
                systemInstruction: systemInstruction,
                contents: contents,
                tools: tools
            )
        } catch let error as GeminiRepositoryError {
            throw error
        } catch {
            throw GeminiRepositoryError.requestFailed(underlying: error)
        }
    }

    // MARK: - Private Methods

    private func decodeChatResponse(from json: String) throws -> ChatResponsePayload {
        do {
            guard let data = json.data(using: .utf8) else {
                throw NSError(domain: "LiveGeminiRepository", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid UTF-8 JSON"
                ])
            }
            return try JSONDecoder().decode(ChatResponsePayload.self, from: data)
        } catch {
            throw GeminiRepositoryError.responseParseFailed(underlying: error)
        }
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "mov":
            return "video/quicktime"
        case "mp4":
            return "video/mp4"
        case "m4v":
            return "video/x-m4v"
        default:
            return "video/mp4"
        }
    }
}

private struct ChatResponsePayload: Decodable {
    let text: String
    let suggestedTemplate: TemplateDTO?
}
