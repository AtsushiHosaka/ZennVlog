import Foundation
import UIKit

protocol ImagenRepositoryProtocol: Sendable {
    func generateGuideImage(prompt: String) async throws -> UIImage
}
