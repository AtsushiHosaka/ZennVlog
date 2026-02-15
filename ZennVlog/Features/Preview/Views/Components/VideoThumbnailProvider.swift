import AVFoundation
import UIKit

actor VideoThumbnailProvider {
    static let shared = VideoThumbnailProvider()

    private let cache = NSCache<NSString, UIImage>()

    func thumbnail(for localFileURL: String?) async -> UIImage? {
        guard let localFileURL else { return nil }

        let cacheKey = NSString(string: localFileURL)
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        guard let videoURL = VideoAssetPathResolver.resolveLocalURL(from: localFileURL) else {
            return nil
        }

        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 320, height: 320)

        do {
            let cgImage = try generator.copyCGImage(
                at: CMTime(seconds: 0, preferredTimescale: 600),
                actualTime: nil
            )
            let image = UIImage(cgImage: cgImage)
            cache.setObject(image, forKey: cacheKey)
            return image
        } catch {
            return nil
        }
    }
}
