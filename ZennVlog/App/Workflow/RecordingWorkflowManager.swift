import Foundation

@MainActor
final class RecordingWorkflowManager {
    private let lifecycleManager: ProjectLifecycleManager

    init(lifecycleManager: ProjectLifecycleManager) {
        self.lifecycleManager = lifecycleManager
    }

    func updateStatusIfReadyForPreview(project: Project) async {
        _ = try? await lifecycleManager.markEditingIfReady(project)
    }
}
