import Foundation
import Testing
@testable import ZennVlog

private actor GeminiDataSourceStub: GeminiRESTDataSourceProtocol {
    var textResponse: String = ""
    var videoResponse: String = ""
    var imageData: Data = Data()

    func setTextResponse(_ value: String) {
        textResponse = value
    }

    func setVideoResponse(_ value: String) {
        videoResponse = value
    }

    func generateText(model: String, systemInstruction: String, messages: [GeminiMessage]) async throws -> String {
        textResponse
    }

    func analyzeVideo(model: String, systemInstruction: String, prompt: String, videoData: Data, mimeType: String) async throws -> String {
        videoResponse
    }

    func generateImage(model: String, prompt: String) async throws -> Data {
        imageData
    }
}

@Suite("LiveGeminiRepository Tests")
struct LiveGeminiRepositoryTests {

    @Test("sendMessage decodes strict JSON")
    func sendMessageDecodesJSON() async throws {
        let stub = GeminiDataSourceStub()
        await stub.setTextResponse(
            """
            {
              "text": "hello",
              "suggestedTemplate": null,
              "suggestedBGM": null
            }
            """
        )

        let repository = LiveGeminiRepository(
            dataSource: stub,
            textModel: "model-text",
            videoModel: "model-video"
        )

        let response = try await repository.sendMessage("hi", history: [])

        #expect(response.text == "hello")
        #expect(response.suggestedTemplate == nil)
        #expect(response.suggestedBGM == nil)
    }

    @Test("sendMessage throws responseParseFailed on invalid JSON")
    func sendMessageThrowsOnInvalidJSON() async throws {
        let stub = GeminiDataSourceStub()
        await stub.setTextResponse("not-json")

        let repository = LiveGeminiRepository(
            dataSource: stub,
            textModel: "model-text",
            videoModel: "model-video"
        )

        do {
            _ = try await repository.sendMessage("hi", history: [])
            #expect(Bool(false), "responseParseFailed should be thrown")
        } catch let error as GeminiRepositoryError {
            switch error {
            case .responseParseFailed:
                #expect(Bool(true))
            default:
                #expect(Bool(false), "unexpected error type")
            }
        }
    }

    @Test("analyzeVideo decodes segments")
    func analyzeVideoDecodesSegments() async throws {
        let stub = GeminiDataSourceStub()
        await stub.setVideoResponse(
            """
            {
              "segments": [
                { "startSeconds": 0.0, "endSeconds": 3.0, "description": "intro" },
                { "startSeconds": 3.0, "endSeconds": 6.0, "description": "main" }
              ]
            }
            """
        )

        let repository = LiveGeminiRepository(
            dataSource: stub,
            textModel: "model-text",
            videoModel: "model-video"
        )

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("gemini-test.mp4")
        try Data([0, 1, 2, 3]).write(to: tempURL)

        let result = try await repository.analyzeVideo(url: tempURL)

        #expect(result.segments.count == 2)
        #expect(result.segments[0].description == "intro")

        try? FileManager.default.removeItem(at: tempURL)
    }
}
