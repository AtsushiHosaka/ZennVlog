import Foundation
import UIKit

final class MockImagenRepository: ImagenRepositoryProtocol, Sendable {

    // MARK: - ImagenRepositoryProtocol

    func generateGuideImage(prompt: String) async throws -> UIImage {
        try await simulateNetworkDelay()
        return createPlaceholderImage(for: prompt)
    }

    // MARK: - Private Methods

    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: 1_500_000_000)
    }

    private func createPlaceholderImage(for prompt: String) -> UIImage {
        let size = CGSize(width: 400, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            UIColor.systemGray5.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.secondaryLabel,
                .paragraphStyle: paragraphStyle
            ]

            let text = "撮影ガイド\n\n\(prompt)"
            let textRect = CGRect(x: 20, y: size.height / 2 - 40, width: size.width - 40, height: 80)
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
}
