import Foundation
import Testing
import UIKit
@testable import ZennVlog

// テスト用MockImagenRepository
// 本番のMockImagenRepositoryはSendable準拠で mutable state を持てないため、
// テスト用に@MainActorのローカルMockを作成
@MainActor
private final class TestMockImagenRepository: ImagenRepositoryProtocol {
    var shouldThrowError: Bool = false
    var lastPrompt: String?
    var callCount: Int = 0

    func generateGuideImage(prompt: String) async throws -> UIImage {
        lastPrompt = prompt
        callCount += 1

        if shouldThrowError {
            throw ImagenRepositoryError.generationFailed(underlying: NSError(domain: "MockTest", code: -1))
        }

        return createPlaceholderImage()
    }

    private func createPlaceholderImage() -> UIImage {
        let size = CGSize(width: 100, height: 75)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

@Suite("GenerateGuideImageUseCase テスト")
@MainActor
struct GenerateGuideImageUseCaseTests {

    @Test("ガイド画像を生成できる")
    func ガイド画像を生成できる() async throws {
        // Given
        let mockRepository = TestMockImagenRepository()
        let useCase = GenerateGuideImageUseCase(repository: mockRepository)

        // When
        let image = try await useCase.execute(prompt: "オープニングの風景")

        // Then
        #expect(image.size.width > 0)
        #expect(image.size.height > 0)
        #expect(mockRepository.callCount == 1)
        #expect(mockRepository.lastPrompt == "オープニングの風景")
    }

    @Test("エラー時に例外がスローされる")
    func エラー時に例外がスローされる() async throws {
        // Given
        let mockRepository = TestMockImagenRepository()
        mockRepository.shouldThrowError = true
        let useCase = GenerateGuideImageUseCase(repository: mockRepository)

        // When & Then
        await #expect(throws: ImagenRepositoryError.self) {
            try await useCase.execute(prompt: "テスト")
        }
    }

    @Test("空のプロンプトでも画像を返す")
    func 空のプロンプトでも画像を返す() async throws {
        // Given
        let mockRepository = TestMockImagenRepository()
        let useCase = GenerateGuideImageUseCase(repository: mockRepository)

        // When
        let image = try await useCase.execute(prompt: "")

        // Then
        #expect(image.size.width > 0)
        #expect(mockRepository.lastPrompt == "")
    }
}
