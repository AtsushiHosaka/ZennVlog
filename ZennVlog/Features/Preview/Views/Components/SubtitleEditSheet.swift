import SwiftUI

struct SubtitleEditSheet: View {
    let maxDuration: Double
    let onSave: (SubtitleSheetState) async -> Bool
    let onDelete: (UUID) async -> Bool
    let onDismiss: () -> Void

    @State private var draft: SubtitleSheetState
    @State private var isProcessing = false
    @State private var localErrorMessage: String?
    @FocusState private var isFocused: Bool

    init(
        initialState: SubtitleSheetState,
        maxDuration: Double,
        onSave: @escaping (SubtitleSheetState) async -> Bool,
        onDelete: @escaping (UUID) async -> Bool,
        onDismiss: @escaping () -> Void
    ) {
        self.maxDuration = maxDuration
        self.onSave = onSave
        self.onDelete = onDelete
        self.onDismiss = onDismiss
        _draft = State(initialValue: initialState)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(timeRangeTitle)
                        .font(.headline)
                }

                Section("テロップ") {
                    TextField("テキストを入力", text: $draft.text, axis: .vertical)
                        .lineLimit(2...4)
                        .focused($isFocused)
                }

                Section("表示時間") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("開始")
                            Spacer()
                            Text(formatTime(draft.startSeconds))
                                .monospacedDigit()
                        }
                        Slider(
                            value: Binding(
                                get: { draft.startSeconds },
                                set: { newValue in
                                    draft.startSeconds = min(newValue, max(draft.endSeconds - 0.1, 0))
                                }
                            ),
                            in: 0...max(maxDuration - 0.1, 0),
                            step: 0.1
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("終了")
                            Spacer()
                            Text(formatTime(draft.endSeconds))
                                .monospacedDigit()
                        }
                        Slider(
                            value: Binding(
                                get: { draft.endSeconds },
                                set: { newValue in
                                    draft.endSeconds = max(newValue, min(draft.startSeconds + 0.1, maxDuration))
                                }
                            ),
                            in: min(draft.startSeconds + 0.1, maxDuration)...maxDuration,
                            step: 0.1
                        )
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
                    .disabled(isProcessing || draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var timeRangeTitle: String {
        "\(formatTime(draft.startSeconds)) - \(formatTime(draft.endSeconds)) のテロップ"
    }

    private func handleSave() async {
        isFocused = false
        localErrorMessage = nil
        isProcessing = true
        defer { isProcessing = false }

        let success = await onSave(draft)
        if !success {
            localErrorMessage = "保存できませんでした。時間範囲と重複を確認してください。"
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
            subtitleId: UUID(),
            startSeconds: 8,
            endSeconds: 12,
            text: "テストテロップ"
        ),
        maxDuration: 40,
        onSave: { _ in true },
        onDelete: { _ in true },
        onDismiss: {}
    )
}
