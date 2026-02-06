import AVFoundation
import Foundation
import Testing
@testable import ZennVlog

/// TrimVideoUseCase テスト
/// 注意: AVFoundation依存のため、実動画ファイルなしではエラーパスのみテスト可能。
/// 実動画を使った統合テストは別途必要。
@Suite("TrimVideoUseCase テスト")
@MainActor
struct TrimVideoUseCaseTests {
    let useCase: TrimVideoUseCase

    init() {
        useCase = TrimVideoUseCase()
    }

    @Test("存在しないファイルでエラーがスローされる")
    func 存在しないファイルでエラーがスローされる() async {
        // Given
        let nonExistentURL = URL(fileURLWithPath: "/nonexistent/video.mp4")

        // When & Then
        await #expect(throws: Error.self) {
            _ = try await useCase.execute(
                videoURL: nonExistentURL,
                startSeconds: 0,
                duration: 5.0
            )
        }
    }

    @Test("TrimError型が正しく定義されている")
    func TrimError型が正しく定義されている() {
        // TrimError.invalidTimeRange
        let invalidRange = TrimVideoUseCase.TrimError.invalidTimeRange
        #expect(invalidRange is Error)

        // TrimError.assetLoadFailed
        let loadFailed = TrimVideoUseCase.TrimError.assetLoadFailed
        #expect(loadFailed is Error)

        // TrimError.exportFailed
        let exportFailed = TrimVideoUseCase.TrimError.exportFailed(
            NSError(domain: "test", code: -1)
        )
        #expect(exportFailed is Error)
    }

    @Test("各エラー型が区別可能である")
    func 各エラー型が区別可能である() {
        // Given
        let error1 = TrimVideoUseCase.TrimError.invalidTimeRange
        let error2 = TrimVideoUseCase.TrimError.assetLoadFailed
        let error3 = TrimVideoUseCase.TrimError.exportFailed(
            NSError(domain: "test", code: -1)
        )

        // Then: パターンマッチングで区別可能
        switch error1 {
        case .invalidTimeRange:
            break // 期待通り
        default:
            Issue.record("invalidTimeRangeが正しくマッチしない")
        }

        switch error2 {
        case .assetLoadFailed:
            break
        default:
            Issue.record("assetLoadFailedが正しくマッチしない")
        }

        switch error3 {
        case .exportFailed:
            break
        default:
            Issue.record("exportFailedが正しくマッチしない")
        }
    }
}
