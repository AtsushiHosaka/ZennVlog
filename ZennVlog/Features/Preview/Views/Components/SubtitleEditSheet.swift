import SwiftUI

struct SubtitleEditSheet: View {
    let onSave: (SubtitleSheetState) async -> String?
    let onDelete: (UUID) async -> Bool
    let onDismiss: () -> Void

    @State private var draft: SubtitleSheetState
    @State private var subtitleText: String
    @State private var isProcessing = false
    @State private var localErrorMessage: String?
    @FocusState private var isTextFocused: Bool

    init(
        initialState: SubtitleSheetState,
        onSave: @escaping (SubtitleSheetState) async -> String?,
        onDelete: @escaping (UUID) async -> Bool,
        onDismiss: @escaping () -> Void
    ) {
        self.onSave = onSave
        self.onDelete = onDelete
        self.onDismiss = onDismiss
        _draft = State(initialValue: initialState)
        _subtitleText = State(initialValue: initialState.text)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(timeRangeTitle)
                        .font(.headline)
                }

                Section("テロップ") {
                    Text("空欄で保存すると、このセグメントのテロップを削除します。")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    ZStack(alignment: .topLeading) {
                        if subtitleText.isEmpty {
                            Text("テキストを入力（任意）")
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.top, 8)
                        }

                        TextEditor(text: $subtitleText)
                            .focused($isTextFocused)
                            .frame(minHeight: 96)
                    }
                }

                Section("表示時間（固定）") {
                    HStack {
                        Text("開始")
                        Spacer()
                        Text(formatTime(draft.startSeconds))
                            .monospacedDigit()
                    }
                    HStack {
                        Text("終了")
                        Spacer()
                        Text(formatTime(draft.endSeconds))
                            .monospacedDigit()
                    }
                }

                if let localErrorMessage {
                    Section {
                        Text(localErrorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }

                if let subtitleId = draft.subtitleId {
                    Section {
                        Button("テロップを削除", role: .destructive) {
                            Task {
                                await handleDelete(subtitleId)
                            }
                        }
                        .disabled(isProcessing)
                    }
                }
            }
            .navigationTitle("テロップ編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        onDismiss()
                    }
                    .disabled(isProcessing)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await handleSave()
                        }
                    } label: {
                        if isProcessing {
                            ProgressView()
                        } else {
                            Text("保存")
                        }
                    }
                    .disabled(isProcessing)
                }
            }
            .onAppear {
                isTextFocused = true
            }
        }
    }

    private var timeRangeTitle: String {
        "S\(draft.segmentOrder + 1) のテロップ"
    }

    private func handleSave() async {
        await MainActor.run {
            isTextFocused = false
        }
        await Task.yield()

        let trimmedText = subtitleText.trimmingCharacters(in: .whitespacesAndNewlines)
        localErrorMessage = nil
        isProcessing = true
        defer { isProcessing = false }

        var saveDraft = draft
        saveDraft.text = trimmedText
        if let errorMessage = await onSave(saveDraft) {
            localErrorMessage = errorMessage
        }
    }

    private func handleDelete(_ subtitleId: UUID) async {
        localErrorMessage = nil
        isProcessing = true
        defer { isProcessing = false }

        let success = await onDelete(subtitleId)
        if !success {
            localErrorMessage = "削除に失敗しました。"
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.down))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview {
    SubtitleEditSheet(
        initialState: SubtitleSheetState(
            segmentOrder: 1,
            subtitleId: UUID(),
            startSeconds: 8,
            endSeconds: 12,
            text: "テストテロップ"
        ),
        onSave: { _ in nil },
        onDelete: { _ in true },
        onDismiss: {}
    )
}
