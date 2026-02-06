import Foundation
import SwiftData

@MainActor
final class SyncChatHistoryUseCase {

    // MARK: - Properties

    private var modelContext: ModelContext?

    // MARK: - Init

    init() {}

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Execute

    func execute(projectId: UUID, message: ChatMessage) async throws {
        guard let modelContext else { return }

        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.id == projectId }
        )

        if let project = try modelContext.fetch(descriptor).first {
            project.chatHistory.append(message)
            project.updatedAt = Date()
            try modelContext.save()
        }
    }
}
