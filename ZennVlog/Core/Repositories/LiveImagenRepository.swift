import Foundation
import UIKit

actor LiveImagenRepository: ImagenRepositoryProtocol {

    // MARK: - Properties

    private let dataSource: any GeminiRESTDataSourceProtocol
    private let imageModel: String

    // MARK: - Init

    init(
        dataSource: any GeminiRESTDataSourceProtocol = GeminiRESTDataSource(
            apiKey: SecretsManager.geminiAPIKey
        ),
        imageModel: String = SecretsManager.geminiImageModel
    ) {
        self.dataSource = dataSource
        self.imageModel = imageModel
    }

    // MARK: - ImagenRepositoryProtocol

    func generateGuideImage(prompt: String) async throws -> UIImage {
        do {
            let imageData = try await dataSource.generateImage(
                model: imageModel,
                prompt: prompt
            )

            guard let image = UIImage(data: imageData) else {
                throw ImagenRepositoryError.invalidImageData
            }

            return image
        } catch let error as ImagenRepositoryError {
            throw error
        } catch {
            throw ImagenRepositoryError.generationFailed(underlying: error)
        }
    }
}
