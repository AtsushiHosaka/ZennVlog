import Foundation
import Testing
@testable import ZennVlog

private actor GeminiRepositorySpy: GeminiRepositoryProtocol {
    var sendMessageCallCount: Int = 0
    var analyzeVideoCallCount: Int = 0
    var nextResponse: GeminiChatResponse
    var analyzeVideoResult: VideoAnalysisResult
    var analyzeVideoError: Error?

    init(
        nextResponse: GeminiChatResponse = GeminiChatResponse(
            text: "ok",
            suggestedTemplate: nil,
            suggestedBGM: nil
        ),
        analyzeVideoResult: VideoAnalysisResult = VideoAnalysisResult(
            segments: [AnalyzedSegment(startSeconds: 0, endSeconds: 5, description: "人物")]
        ),
        analyzeVideoError: Error? = nil
    ) {
        self.nextResponse = nextResponse
        self.analyzeVideoResult = analyzeVideoResult
        self.analyzeVideoError = analyzeVideoError
    }

    func sendMessage(_ message: String, history: [ChatMessageDTO]) async throws -> GeminiChatResponse {
        sendMessageCallCount += 1
        return nextResponse
    }

    func analyzeVideo(url: URL) async throws -> VideoAnalysisResult {
        analyzeVideoCallCount += 1
        if let analyzeVideoError {
            throw analyzeVideoError
        }
        return analyzeVideoResult
    }
}

private enum ChatViewModelActionTestError: Error {
    case failed
}

@Suite("ChatViewModel Action Tests")
@MainActor
struct ChatViewModelActionTests {

    @Test("このテンプレートを使うは操作として確定しAI送信しない")
    func quickReplyConfirmTemplateDoesNotSendAI() async {
        let geminiRepository = GeminiRepositorySpy()
        let viewModel = makeViewModel(repository: geminiRepository)
        viewModel.selectedTemplate = sampleTemplate()

        await viewModel.sendQuickReply("このテンプレートを使う")

        #expect(viewModel.isTemplateConfirmed)
        #expect(viewModel.messages.last?.content == "このテンプレートを使う")
        #expect(await geminiRepository.sendMessageCallCount == 0)
    }

    @Test("このBGMを使うは操作として確定しAI送信しない")
    func quickReplyConfirmBGMDoesNotSendAI() async {
        let geminiRepository = GeminiRepositorySpy()
        let viewModel = makeViewModel(repository: geminiRepository)
        viewModel.selectedBGM = sampleBGM()

        await viewModel.sendQuickReply("このBGMを使う")

        #expect(viewModel.selectedBGM?.id == "bgm-1")
        #expect(viewModel.messages.last?.content == "このBGMを使う")
        #expect(await geminiRepository.sendMessageCallCount == 0)
    }

    @Test("他のテンプレートを見るは通常送信される")
    func quickReplyOtherTemplateGoesThroughAI() async {
        let geminiRepository = GeminiRepositorySpy()
        let viewModel = makeViewModel(repository: geminiRepository)

        await viewModel.sendQuickReply("他のテンプレートを見る")

        #expect(await geminiRepository.sendMessageCallCount == 1)
        #expect(viewModel.messages.count >= 2)
    }

    @Test("添付付き送信でユーザーメッセージにattachedVideoURLが保存される")
    func attachedVideoPersistsToMessage() async {
        let geminiRepository = GeminiRepositorySpy()
        let viewModel = makeViewModel(repository: geminiRepository)
        let url = URL(fileURLWithPath: "/tmp/movie.mp4")
        viewModel.attachVideo(url)
        viewModel.inputText = "動画を見てください"

        await viewModel.sendMessage()

        #expect(viewModel.messages.first?.attachedVideoURL == url.absoluteString)
    }

    @Test("添付付き送信の後に動画解析結果が会話へ追加される")
    func attachedVideoTriggersBackgroundAnalysis() async {
        let geminiRepository = GeminiRepositorySpy(
            analyzeVideoResult: VideoAnalysisResult(
                segments: [AnalyzedSegment(startSeconds: 1, endSeconds: 4, description: "屋外")]
            )
        )
        let viewModel = makeViewModel(repository: geminiRepository)
        viewModel.attachVideo(URL(fileURLWithPath: "/tmp/movie.mp4"))
        viewModel.inputText = "解析してください"

        await viewModel.sendMessage()
        await waitUntil { viewModel.messages.contains(where: { $0.content.contains("動画の解析が完了しました") }) }

        #expect(await geminiRepository.analyzeVideoCallCount == 1)
        #expect(viewModel.messages.contains(where: { $0.content.contains("動画の解析が完了しました") }))
    }

    @Test("動画解析失敗時はエラー表示のみで会話継続")
    func attachedVideoAnalysisFailureSetsErrorOnly() async {
        let geminiRepository = GeminiRepositorySpy(analyzeVideoError: ChatViewModelActionTestError.failed)
        let viewModel = makeViewModel(repository: geminiRepository)
        viewModel.attachVideo(URL(fileURLWithPath: "/tmp/movie.mp4"))
        viewModel.inputText = "解析してください"

        await viewModel.sendMessage()
        await waitUntil { viewModel.errorMessage != nil }

        #expect(await geminiRepository.analyzeVideoCallCount == 1)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.messages.count >= 2)
    }

    private func makeViewModel(repository: GeminiRepositoryProtocol) -> ChatViewModel {
        ChatViewModel(
            sendMessageUseCase: SendMessageWithAIUseCase(repository: repository),
            fetchTemplatesUseCase: FetchTemplatesUseCase(repository: MockTemplateRepository()),
            analyzeVideoUseCase: AnalyzeVideoUseCase(repository: repository),
            syncChatHistoryUseCase: SyncChatHistoryUseCase(),
            initializeChatSessionUseCase: InitializeChatSessionUseCase()
        )
    }

    private func sampleTemplate() -> TemplateDTO {
        TemplateDTO(
            id: "template-1",
            name: "Sample",
            description: "desc",
            referenceVideoUrl: "https://example.com",
            explanation: "exp",
            segments: [SegmentDTO(order: 0, startSec: 0, endSec: 5, description: "seg")]
        )
    }

    private func sampleBGM() -> BGMTrack {
        BGMTrack(
            id: "bgm-1",
            title: "title",
            description: "desc",
            genre: "pop",
            duration: 120,
            storageUrl: "gs://bucket/file.m4a",
            tags: []
        )
    }

    private func waitUntil(
        timeoutNanos: UInt64 = 500_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let deadline = ContinuousClock.now + .nanoseconds(Int64(timeoutNanos))
        while ContinuousClock.now < deadline {
            if condition() {
                return
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}
