import SwiftUI

struct BGMSettingsSheet: View {
    let bgmTracks: [BGMTrack]
    let initialSelectedBGM: BGMTrack?
    let initialVolume: Float
    let onSave: (BGMTrack?, Float) async -> Bool
    let onDismiss: () -> Void

    @State private var selectedBGMId: String?
    @State private var volume: Float
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        bgmTracks: [BGMTrack],
        initialSelectedBGM: BGMTrack?,
        initialVolume: Float,
        onSave: @escaping (BGMTrack?, Float) async -> Bool,
        onDismiss: @escaping () -> Void
    ) {
        self.bgmTracks = bgmTracks
        self.initialSelectedBGM = initialSelectedBGM
        self.initialVolume = initialVolume
        self.onSave = onSave
        self.onDismiss = onDismiss
        _selectedBGMId = State(initialValue: initialSelectedBGM?.id)
        _volume = State(initialValue: initialVolume)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("音量") {
                    HStack {
                        Image(systemName: "speaker.fill")
                            .foregroundColor(.secondary)
                        Slider(value: $volume, in: 0...1)
                        Text("\(Int(volume * 100))%")
                            .monospacedDigit()
                            .frame(width: 42)
                    }
                }

                Section("BGM") {
                    Button("BGMなし") {
                        selectedBGMId = nil
                    }
                    .foregroundColor(selectedBGMId == nil ? .accentColor : .primary)

                    ForEach(bgmTracks, id: \.id) { track in
                        Button {
                            selectedBGMId = track.id
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.title)
                                    Text(track.genre)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if selectedBGMId == track.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("BGM設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        onDismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await handleSave()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("保存")
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func handleSave() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        let selectedTrack = bgmTracks.first { $0.id == selectedBGMId }
        let success = await onSave(selectedTrack, volume)
        if !success {
            errorMessage = "BGM設定を保存できませんでした。"
        }
    }
}

#Preview {
    BGMSettingsSheet(
        bgmTracks: [
            BGMTrack(
                id: "bgm-1",
                title: "Morning",
                description: "",
                genre: "Pop",
                duration: 120,
                storageUrl: "mock://bgm/1",
                tags: []
            ),
            BGMTrack(
                id: "bgm-2",
                title: "Chill",
                description: "",
                genre: "Lo-fi",
                duration: 180,
                storageUrl: "mock://bgm/2",
                tags: []
            )
        ],
        initialSelectedBGM: nil,
        initialVolume: 0.3,
        onSave: { _, _ in true },
        onDismiss: {}
    )
}
