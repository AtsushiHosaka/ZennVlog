import Foundation
import Testing
import UIKit
@testable import ZennVlog

private actor ImagenDataSourceStub: GeminiRESTDataSourceProtocol {
    var imageData: Data = Data()

    func setImageData(_ data: Data) {
        imageData = data
    }

    func generateText(model: String, systemInstruction: String, messages: [GeminiMessage]) async throws -> String {
        ""
    }

    func analyzeVideo(model: String, systemInstruction: String, prompt: String, videoData: Data, mimeType: String) async throws -> String {
        ""
    }

    func generateImage(model: String, prompt: String) async throws -> Data {
        imageData
    }
}

@Suite("LiveImagenRepository Tests")
struct LiveImagenRepositoryTests {

    private func makePNGData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2))
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        return image.pngData() ?? Data()
    }

    @Test("generateGuideImage decodes image data")
    func generateGuideImageDecodesImageData() async throws {
        let stub = ImagenDataSourceStub()
        await stub.setImageData(makePNGData())

        let repository = LiveImagenRepository(
            dataSource: stub,
            imageModel: "model-image"
        )

        let image = try await repository.generateGuideImage(prompt: "scene")

        #expect(image.size.width > 0)
        #expect(image.size.height > 0)
    }

    @Test("generateGuideImage throws invalidImageData")
    func generateGuideImageThrowsInvalidImageData() async throws {
        let stub = ImagenDataSourceStub()
        await stub.setImageData(Data("broken".utf8))

        let repository = LiveImagenRepository(
            dataSource: stub,
            imageModel: "model-image"
        )

        do {
            _ = try await repository.generateGuideImage(prompt: "scene")
            #expect(Bool(false), "invalidImageData should be thrown")
        } catch let error as ImagenRepositoryError {
            switch error {
            case .invalidImageData:
                #expect(Bool(true))
            default:
                #expect(Bool(false), "unexpected error type")
            }
        }
    }
}
