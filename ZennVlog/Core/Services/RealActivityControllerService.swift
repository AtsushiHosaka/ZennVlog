import UIKit

/// アクティビティコントローラーサービスの本番実装
@MainActor
final class RealActivityControllerService: ActivityControllerServiceProtocol {

    func share(items: [Any]) async -> Bool {
        await withCheckedContinuation { continuation in
            // UIActivityViewControllerを作成
            let activityViewController = UIActivityViewController(
                activityItems: items,
                applicationActivities: nil
            )

            // 完了ハンドラを設定
            activityViewController.completionWithItemsHandler = { _, completed, _, _ in
                continuation.resume(returning: completed)
            }

            // ルートビューコントローラーを取得して表示
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {

                // iPadの場合はポップオーバーとして表示
                if let popoverController = activityViewController.popoverPresentationController {
                    popoverController.sourceView = rootViewController.view
                    popoverController.sourceRect = CGRect(
                        x: rootViewController.view.bounds.midX,
                        y: rootViewController.view.bounds.midY,
                        width: 0,
                        height: 0
                    )
                    popoverController.permittedArrowDirections = []
                }

                rootViewController.present(activityViewController, animated: true)
            } else {
                // ルートビューコントローラーが取得できない場合はキャンセル扱い
                continuation.resume(returning: false)
            }
        }
    }
}
