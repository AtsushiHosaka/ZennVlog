import AVFoundation
import CoreGraphics
import Foundation

enum SegmentCompositionAssemblerError: Error {
    case videoTrackCreationFailed
    case audioTrackCreationFailed
    case legacyAssetNotFound(String)
    case legacyAssetInvalidDuration(String)
    case legacyTrimOutOfRange(String)
}

enum SegmentCompositionAssembler {
    struct BuildResult {
        let composition: AVMutableComposition
        let videoTrack: AVMutableCompositionTrack
        let audioTrack: AVMutableCompositionTrack?
        let targetAssetCount: Int
        let resolvedAssetCount: Int
        let insertedAssetCount: Int
        let insertedAnyTrack: Bool
        let duration: CMTime
        let preferredTransform: CGAffineTransform?
        let videoSize: CGSize
    }

    static func build(
        videoAssets: [VideoAsset],
        segments: [Segment],
        requiresPrimaryAudioTrack: Bool,
        strictOnLegacyMissingAsset: Bool
    ) async throws -> BuildResult {
        let sortedAssets = videoAssets
            .filter { $0.segmentOrder != nil }
            .sorted { ($0.segmentOrder ?? 0) < ($1.segmentOrder ?? 0) }
        let sortedSegments = segments.sorted { lhs, rhs in
            if lhs.startSeconds == rhs.startSeconds {
                return lhs.order < rhs.order
            }
            return lhs.startSeconds < rhs.startSeconds
        }

        let composition = AVMutableComposition()
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw SegmentCompositionAssemblerError.videoTrackCreationFailed
        }

        let compositionAudioTrack: AVMutableCompositionTrack?
        if requiresPrimaryAudioTrack {
            guard let requiredAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                throw SegmentCompositionAssemblerError.audioTrackCreationFailed
            }
            compositionAudioTrack = requiredAudioTrack
        } else {
            compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        }

        var currentInsertTime = CMTime.zero
        var insertedAnyTrack = false
        var resolvedAssetCount = 0
        var insertedAssetCount = 0
        var preferredTransform: CGAffineTransform?
        var videoSize = CGSize(width: 1920, height: 1080)

        if !sortedSegments.isEmpty {
            var assetByOrder: [Int: VideoAsset] = [:]
            for asset in sortedAssets {
                guard let order = asset.segmentOrder else { continue }
                if assetByOrder[order] == nil {
                    assetByOrder[order] = asset
                }
            }

            for segment in sortedSegments {
                let segmentStart = max(0, segment.startSeconds)
                let segmentEnd = max(segmentStart, segment.endSeconds)
                let segmentDurationSeconds = segmentEnd - segmentStart
                guard segmentDurationSeconds > 0 else { continue }

                let segmentStartTime = CMTime(seconds: segmentStart, preferredTimescale: 600)
                if CMTimeCompare(segmentStartTime, currentInsertTime) > 0 {
                    let gapDuration = CMTimeSubtract(segmentStartTime, currentInsertTime)
                    insertEmptyRange(
                        duration: gapDuration,
                        at: currentInsertTime,
                        videoTrack: compositionVideoTrack,
                        audioTrack: compositionAudioTrack
                    )
                    currentInsertTime = segmentStartTime
                }

                let segmentDuration = CMTime(seconds: segmentDurationSeconds, preferredTimescale: 600)
                let segmentInsertStart = currentInsertTime
                var insertedDuration = CMTime.zero

                if let asset = assetByOrder[segment.order],
                   let localURL = VideoAssetPathResolver.resolveLocalURL(from: asset.localFileURL) {
                    resolvedAssetCount += 1
                    let avAsset = AVURLAsset(url: localURL)

                    if let sourceVideoTrack = try? await avAsset.loadTracks(withMediaType: .video).first {
                        let sourcePreferredTransform = (try? await sourceVideoTrack.load(.preferredTransform))
                            ?? .identity
                        let assetDurationTime = (try? await avAsset.load(.duration))
                            ?? CMTime(seconds: asset.duration, preferredTimescale: 600)
                        let assetDuration = CMTimeGetSeconds(assetDurationTime)
                        let availableDuration = max(0, assetDuration - asset.trimStartSeconds)

                        if assetDuration.isFinite, availableDuration > 0 {
                            let clipDurationSeconds = min(segmentDurationSeconds, availableDuration)
                            if clipDurationSeconds > 0 {
                                let sourceStart = CMTime(seconds: asset.trimStartSeconds, preferredTimescale: 600)
                                let sourceDuration = CMTime(seconds: clipDurationSeconds, preferredTimescale: 600)
                                let sourceRange = CMTimeRange(start: sourceStart, duration: sourceDuration)

                                do {
                                    try compositionVideoTrack.insertTimeRange(
                                        sourceRange,
                                        of: sourceVideoTrack,
                                        at: segmentInsertStart
                                    )
                                    if let sourceAudioTrack = try? await avAsset.loadTracks(withMediaType: .audio).first,
                                       let compositionAudioTrack {
                                        try compositionAudioTrack.insertTimeRange(
                                            sourceRange,
                                            of: sourceAudioTrack,
                                            at: segmentInsertStart
                                        )
                                    }

                                    if preferredTransform == nil {
                                        preferredTransform = sourcePreferredTransform
                                        let naturalSize = (try? await sourceVideoTrack.load(.naturalSize))
                                            ?? CGSize(width: 1920, height: 1080)
                                        let transformedRect = CGRect(origin: .zero, size: naturalSize)
                                            .applying(sourcePreferredTransform)
                                        videoSize = CGSize(
                                            width: max(abs(transformedRect.width), 1),
                                            height: max(abs(transformedRect.height), 1)
                                        )
                                    }

                                    insertedAnyTrack = true
                                    insertedAssetCount += 1
                                    insertedDuration = sourceDuration
                                } catch {
                                    insertedDuration = .zero
                                }
                            }
                        }
                    }
                }

                if CMTimeCompare(insertedDuration, segmentDuration) < 0 {
                    let remaining = CMTimeSubtract(segmentDuration, insertedDuration)
                    let remainderStart = CMTimeAdd(segmentInsertStart, insertedDuration)
                    insertEmptyRange(
                        duration: remaining,
                        at: remainderStart,
                        videoTrack: compositionVideoTrack,
                        audioTrack: compositionAudioTrack
                    )
                }

                currentInsertTime = CMTimeAdd(segmentInsertStart, segmentDuration)
            }

            if let templateEndSeconds = sortedSegments.map(\.endSeconds).max() {
                let templateEnd = CMTime(seconds: max(0, templateEndSeconds), preferredTimescale: 600)
                if CMTimeCompare(templateEnd, currentInsertTime) > 0 {
                    let tailGap = CMTimeSubtract(templateEnd, currentInsertTime)
                    insertEmptyRange(
                        duration: tailGap,
                        at: currentInsertTime,
                        videoTrack: compositionVideoTrack,
                        audioTrack: compositionAudioTrack
                    )
                    currentInsertTime = templateEnd
                }
            }
        } else {
            for asset in sortedAssets {
                guard let localURL = VideoAssetPathResolver.resolveLocalURL(from: asset.localFileURL) else {
                    if strictOnLegacyMissingAsset {
                        throw SegmentCompositionAssemblerError.legacyAssetNotFound(asset.localFileURL)
                    }
                    continue
                }
                resolvedAssetCount += 1

                let avAsset = AVURLAsset(url: localURL)
                let assetDurationTime = (try? await avAsset.load(.duration))
                    ?? CMTime(seconds: asset.duration, preferredTimescale: 600)
                let assetDuration = CMTimeGetSeconds(assetDurationTime)
                guard assetDuration.isFinite, assetDuration > 0 else {
                    if strictOnLegacyMissingAsset {
                        throw SegmentCompositionAssemblerError.legacyAssetInvalidDuration(localURL.lastPathComponent)
                    }
                    continue
                }

                let availableDuration = max(0, assetDuration - asset.trimStartSeconds)
                guard availableDuration > 0 else {
                    if strictOnLegacyMissingAsset {
                        throw SegmentCompositionAssemblerError.legacyTrimOutOfRange(localURL.lastPathComponent)
                    }
                    continue
                }

                guard let sourceVideoTrack = try? await avAsset.loadTracks(withMediaType: .video).first else {
                    continue
                }
                let sourcePreferredTransform = (try? await sourceVideoTrack.load(.preferredTransform))
                    ?? .identity

                let clipDurationSeconds = min(max(0.1, asset.duration), availableDuration)
                let sourceStart = CMTime(seconds: asset.trimStartSeconds, preferredTimescale: 600)
                let sourceDuration = CMTime(seconds: clipDurationSeconds, preferredTimescale: 600)
                let sourceRange = CMTimeRange(start: sourceStart, duration: sourceDuration)

                do {
                    try compositionVideoTrack.insertTimeRange(sourceRange, of: sourceVideoTrack, at: currentInsertTime)

                    if let sourceAudioTrack = try? await avAsset.loadTracks(withMediaType: .audio).first,
                       let compositionAudioTrack {
                        try compositionAudioTrack.insertTimeRange(sourceRange, of: sourceAudioTrack, at: currentInsertTime)
                    }

                    if preferredTransform == nil {
                        preferredTransform = sourcePreferredTransform
                        let naturalSize = (try? await sourceVideoTrack.load(.naturalSize))
                            ?? CGSize(width: 1920, height: 1080)
                        let transformedRect = CGRect(origin: .zero, size: naturalSize)
                            .applying(sourcePreferredTransform)
                        videoSize = CGSize(
                            width: max(abs(transformedRect.width), 1),
                            height: max(abs(transformedRect.height), 1)
                        )
                    }

                    currentInsertTime = CMTimeAdd(currentInsertTime, sourceDuration)
                    insertedAnyTrack = true
                    insertedAssetCount += 1
                } catch {
                    continue
                }
            }
        }

        return BuildResult(
            composition: composition,
            videoTrack: compositionVideoTrack,
            audioTrack: compositionAudioTrack,
            targetAssetCount: sortedAssets.count,
            resolvedAssetCount: resolvedAssetCount,
            insertedAssetCount: insertedAssetCount,
            insertedAnyTrack: insertedAnyTrack,
            duration: currentInsertTime,
            preferredTransform: preferredTransform,
            videoSize: videoSize
        )
    }

    private static func insertEmptyRange(
        duration: CMTime,
        at start: CMTime,
        videoTrack: AVMutableCompositionTrack,
        audioTrack: AVMutableCompositionTrack?
    ) {
        guard CMTimeCompare(duration, .zero) > 0 else { return }
        let range = CMTimeRange(start: start, duration: duration)
        videoTrack.insertEmptyTimeRange(range)
        audioTrack?.insertEmptyTimeRange(range)
    }
}
