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

private actor VideoAnalysisJobDataSourceStub: VideoAnalysisJobDataSourceProtocol {
    var response = VideoAnalysisResult(segments: [])
    var thrownError: Error?
    var receivedMimeType: String?

    func setResponse(_ value: VideoAnalysisResult) {
        response = value
    }

    func setError(_ value: Error?) {
        thrownError = value
    }

    func analyzeVideo(url: URL, mimeType: String, projectId: String?) async throws -> VideoAnalysisResult {
        receivedMimeType = mimeType
        if let thrownError {
            throw thrownError
        }
        return response
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
            videoAnalysisDataSource: VideoAnalysisJobDataSourceStub(),
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
            videoAnalysisDataSource: VideoAnalysisJobDataSourceStub(),
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
        let geminiStub = GeminiDataSourceStub()
        let jobStub = VideoAnalysisJobDataSourceStub()
        await jobStub.setResponse(
            VideoAnalysisResult(
                segments: [
                    AnalyzedSegment(startSeconds: 0, endSeconds: 3, description: "intro"),
                    AnalyzedSegment(startSeconds: 3, endSeconds: 6, description: "main", confidence: 0.84)
                ]
            )
        )

        let repository = LiveGeminiRepository(
            dataSource: geminiStub,
            videoAnalysisDataSource: jobStub,
            textModel: "model-text",
            videoModel: "model-video"
        )

        let tempURL = URL(fileURLWithPath: "/tmp/gemini-test.mp4")

        let result = try await repository.analyzeVideo(url: tempURL)

        #expect(result.segments.count == 2)
        #expect(result.segments[0].description == "intro")
        #expect(result.segments[1].confidence == 0.84)
        #expect(await jobStub.receivedMimeType == "video/mp4")
    }

    @Test("analyzeVideo maps unknown errors to videoAnalysisFailed")
    func analyzeVideoMapsUnknownErrors() async throws {
        let geminiStub = GeminiDataSourceStub()
        let jobStub = VideoAnalysisJobDataSourceStub()
        await jobStub.setError(NSError(domain: "test", code: 42))

        let repository = LiveGeminiRepository(
            dataSource: geminiStub,
            videoAnalysisDataSource: jobStub,
            textModel: "model-text",
            videoModel: "model-video"
        )

        do {
            _ = try await repository.analyzeVideo(url: URL(fileURLWithPath: "/tmp/any.mov"))
            #expect(Bool(false), "videoAnalysisFailed should be thrown")
        } catch let error as GeminiRepositoryError {
            switch error {
            case .videoAnalysisFailed:
                #expect(Bool(true))
            default:
                #expect(Bool(false), "unexpected error type")
            }
        }
    }
}
