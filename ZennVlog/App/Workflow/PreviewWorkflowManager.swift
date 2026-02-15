import Foundation

@MainActor
final class PreviewWorkflowManager {
    private let lifecycleManager: ProjectLifecycleManager

    init(lifecycleManager: ProjectLifecycleManager) {
        self.lifecycleManager = lifecycleManager
    }

    func normalizeTimelineTime(
        _ value: Double,
        duration: Double,
        precision: Double
    ) -> Double {
        let clamped: Double
        if duration > 0 {
            clamped = min(max(0, value), duration)
        } else {
            clamped = max(0, value)
        }
        return (clamped * precision).rounded() / precision
    }

    func nextSubtitleRange(
        around currentTime: Double,
        duration: Double,
        existingSubtitles: [Subtitle],
        defaultLength: Double = 2.0,
        minimumLength: Double = 0.1
    ) -> (start: Double, end: Double) {
        let sorted = existingSubtitles.sorted { $0.startSeconds < $1.startSeconds }
        let boundedDuration = max(duration, 0)

        func makeRange(start: Double, maxEnd: Double) -> (Double, Double)? {
            let candidateEnd = min(start + defaultLength, maxEnd)
            guard candidateEnd - start >= minimumLength else { return nil }
            return (start, candidateEnd)
        }

        // 1. Prefer the nearest range at currentTime.
        let normalizedCurrent = min(max(currentTime, 0), boundedDuration)
        var cursor = normalizedCurrent
        for subtitle in sorted where subtitle.endSeconds <= cursor {
            cursor = max(cursor, subtitle.endSeconds)
        }
        let nextStart = sorted.first(where: { $0.startSeconds >= cursor })?.startSeconds ?? boundedDuration
        if let range = makeRange(start: cursor, maxEnd: nextStart) {
            return range
        }

        // 2. Fallback to first empty window from the start.
        cursor = 0
        for subtitle in sorted {
            if let range = makeRange(start: cursor, maxEnd: subtitle.startSeconds) {
                return range
            }
            cursor = max(cursor, subtitle.endSeconds)
        }
        if let range = makeRange(start: cursor, maxEnd: boundedDuration) {
            return range
        }

        // 3. Last resort: tiny range at tail.
        let safeEnd = boundedDuration
        let safeStart = max(0, safeEnd - minimumLength)
        return (safeStart, safeEnd)
    }

    func markCompleted(project: Project) async throws {
        try await lifecycleManager.markCompleted(project)
    }
}
