import Foundation

struct GeminiMessage: Sendable {
    let role: String
    let text: String
}

protocol GeminiRESTDataSourceProtocol: Sendable {
    func generateText(
        model: String,
        systemInstruction: String,
        messages: [GeminiMessage]
    ) async throws -> String

    func analyzeVideo(
        model: String,
        systemInstruction: String,
        prompt: String,
        videoData: Data,
        mimeType: String
    ) async throws -> String

    func generateImage(
        model: String,
        prompt: String
    ) async throws -> Data
}

actor GeminiRESTDataSource: GeminiRESTDataSourceProtocol {

    // MARK: - Properties

    private let apiKey: String
    private let httpClient: any HTTPClientProtocol
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    // MARK: - Init

    init(
        apiKey: String,
        httpClient: any HTTPClientProtocol = HTTPClient()
    ) {
        self.apiKey = apiKey
        self.httpClient = httpClient
    }

    // MARK: - GeminiRESTDataSourceProtocol

    func generateText(
        model: String,
        systemInstruction: String,
        messages: [GeminiMessage]
    ) async throws -> String {
        let payload = GeminiGenerateRequest(
            systemInstruction: GeminiSystemInstruction(
                parts: [GeminiTextPart(text: systemInstruction)]
            ),
            contents: messages.map { message in
                GeminiContent(
                    role: message.role,
                    parts: [.text(GeminiTextPart(text: message.text))]
                )
            },
            generationConfig: GeminiGenerationConfig(
                responseMimeType: "application/json",
                responseModalities: nil
            )
        )

        return try await generateText(model: model, payload: payload)
    }

    func analyzeVideo(
        model: String,
        systemInstruction: String,
        prompt: String,
        videoData: Data,
        mimeType: String
    ) async throws -> String {
        let payload = GeminiGenerateRequest(
            systemInstruction: GeminiSystemInstruction(
                parts: [GeminiTextPart(text: systemInstruction)]
            ),
            contents: [
                GeminiContent(
                    role: "user",
                    parts: [
                        .text(GeminiTextPart(text: prompt)),
                        .inlineData(
                            GeminiInlineDataPart(
                                inlineData: GeminiInlineData(
                                    mimeType: mimeType,
                                    data: videoData.base64EncodedString()
                                )
                            )
                        )
                    ]
                )
            ],
            generationConfig: GeminiGenerationConfig(
                responseMimeType: "application/json",
                responseModalities: nil
            )
        )

        return try await generateText(model: model, payload: payload)
    }

    func generateImage(model: String, prompt: String) async throws -> Data {
        let payload = GeminiGenerateRequest(
            systemInstruction: nil,
            contents: [
                GeminiContent(
                    role: "user",
                    parts: [.text(GeminiTextPart(text: prompt))]
                )
            ],
            generationConfig: GeminiGenerationConfig(
                responseMimeType: nil,
                responseModalities: ["TEXT", "IMAGE"]
            )
        )

        let requestURL = try makeURL(for: model)
        let body = try encoder.encode(payload)

        let response = try await httpClient.post(
            url: requestURL,
            body: body,
            headers: ["Content-Type": "application/json"]
        )

        let parsed = try decoder.decode(GeminiGenerateResponse.self, from: response.data)

        guard let candidates = parsed.candidates,
              let first = candidates.first,
              let parts = first.content?.parts,
              let imagePart = parts.first(where: { $0.inlineData?.data != nil }),
              let base64 = imagePart.inlineData?.data,
              let data = Data(base64Encoded: base64) else {
            throw ImagenRepositoryError.invalidImageData
        }

        return data
    }

    // MARK: - Private Methods

    private func generateText(
        model: String,
        payload: GeminiGenerateRequest
    ) async throws -> String {
        let requestURL = try makeURL(for: model)
        let body = try encoder.encode(payload)

        let response = try await httpClient.post(
            url: requestURL,
            body: body,
            headers: ["Content-Type": "application/json"]
        )

        let parsed = try decoder.decode(GeminiGenerateResponse.self, from: response.data)

        guard let text = parsed.candidates?.first?.content?.parts?.first(where: { $0.text != nil })?.text,
              !text.isEmpty else {
            throw GeminiRepositoryError.responseParseFailed(
                underlying: NSError(domain: "GeminiRESTDataSource", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "No text response found"
                ])
            )
        }

        return text
    }

    private func makeURL(for model: String) throws -> URL {
        guard let escapedModel = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              var components = URLComponents(
                string: "https://generativelanguage.googleapis.com/v1beta/models/\(escapedModel):generateContent"
              ) else {
            throw URLError(.badURL)
        }

        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey)
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        return url
    }
}

private struct GeminiGenerateRequest: Encodable {
    let systemInstruction: GeminiSystemInstruction?
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig?

    enum CodingKeys: String, CodingKey {
        case systemInstruction = "system_instruction"
        case contents
        case generationConfig
    }
}

private struct GeminiSystemInstruction: Encodable {
    let parts: [GeminiTextPart]
}

private struct GeminiGenerationConfig: Encodable {
    let responseMimeType: String?
    let responseModalities: [String]?

    enum CodingKeys: String, CodingKey {
        case responseMimeType
        case responseModalities
    }
}

private struct GeminiContent: Encodable {
    let role: String
    let parts: [GeminiRequestPart]
}

private enum GeminiRequestPart: Encodable {
    case text(GeminiTextPart)
    case inlineData(GeminiInlineDataPart)

    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let value):
            try value.encode(to: encoder)
        case .inlineData(let value):
            try value.encode(to: encoder)
        }
    }
}

private struct GeminiTextPart: Encodable {
    let text: String
}

private struct GeminiInlineDataPart: Encodable {
    let inlineData: GeminiInlineData

    enum CodingKeys: String, CodingKey {
        case inlineData
    }
}

private struct GeminiInlineData: Encodable {
    let mimeType: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case mimeType
        case data
    }
}

private struct GeminiGenerateResponse: Decodable {
    let candidates: [GeminiCandidate]?
}

private struct GeminiCandidate: Decodable {
    let content: GeminiResponseContent?
}

private struct GeminiResponseContent: Decodable {
    let parts: [GeminiResponsePart]?
}

private struct GeminiResponsePart: Decodable {
    let text: String?
    let inlineData: GeminiResponseInlineData?

    enum CodingKeys: String, CodingKey {
        case text
        case inlineData
    }
}

private struct GeminiResponseInlineData: Decodable {
    let mimeType: String?
    let data: String?

    enum CodingKeys: String, CodingKey {
        case mimeType
        case data
    }
}
