import Foundation
import UIKit

@MainActor
final class GenerateGuideImageUseCase {

    // MARK: - Properties

    private let repository: ImagenRepositoryProtocol

    // MARK: - Init

    init(repository: ImagenRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Execute

    /// 撮影ガイド画像を生成する
    /// - Parameter prompt: セグメントの説明文（撮影内容の説明）
    /// - Returns: 生成されたガイド画像
    func execute(prompt: String) async throws -> UIImage {
        try await repository.generateGuideImage(prompt: prompt)
    }
}
