import PhotosUI
import SwiftUI

struct ChatView: View {
    @State private var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showPhotoPicker: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var scrollProxy: ScrollViewProxy?

    let onTemplateConfirmed: (TemplateDTO, BGMTrack?) -> Void

    init(
        viewModel: ChatViewModel,
        onTemplateConfirmed: @escaping (TemplateDTO, BGMTrack?) -> Void
    ) {
        _viewModel = State(wrappedValue: viewModel)
        self.onTemplateConfirmed = onTemplateConfirmed
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList

                Divider()

                if !viewModel.quickReplies.isEmpty {
                    QuickReplyButtons(replies: viewModel.quickReplies) { reply in
                        Task {
                            await viewModel.sendQuickReply(reply)
                        }
                    }
                    .padding(.vertical, 8)
                }

                ChatInputView(
                    text: $viewModel.inputText,
                    isLoading: viewModel.isLoading,
                    attachedVideoURL: viewModel.attachedVideoURL,
                    onSend: {
                        Task {
                            await viewModel.sendMessage()
                            scrollToBottom()
                        }
                    },
                    onAttachVideo: {
                        showPhotoPicker = true
                    },
                    onRemoveVideo: {
                        viewModel.removeAttachedVideo()
                    }
                )
            }
            .navigationTitle("Vlogを作ろう")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }

                if viewModel.selectedTemplate != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("撮影開始") {
                            confirmTemplate()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $selectedPhotoItem,
                matching: .videos
            )
            .onChange(of: selectedPhotoItem) { _, newItem in
                handleVideoSelection(newItem)
            }
            .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .task {
                await viewModel.startConversation()
            }
        }
    }

    @ViewBuilder
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }

                    // Streaming message
                    if viewModel.isLoading && !viewModel.streamingText.isEmpty {
                        ChatBubble(
                            message: ChatMessage(
                                role: .assistant,
                                content: viewModel.streamingText
                            ),
                            isStreaming: true
                        )
                    }

                    // Loading indicator
                    if viewModel.isLoading && viewModel.streamingText.isEmpty {
                        loadingIndicator
                    }

                    if viewModel.isAnalyzingVideo {
                        videoAnalysisIndicator
                    }

                    // Template Preview
                    if let template = viewModel.selectedTemplate {
                        templatePreview(template)
                    }

                    // BGM Preview
                    if let bgm = viewModel.selectedBGM {
                        bgmPreview(bgm)
                    }

                    Spacer()
                        .frame(height: 20)
                        .id("bottom")
                }
                .padding(.top, 16)
            }
            .onAppear {
                scrollProxy = proxy
            }
        }
    }

    @ViewBuilder
    private var loadingIndicator: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                        .opacity(0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: viewModel.isLoading
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 18))

            Spacer()
        }
        .padding(.horizontal)
        .padding(.leading, 40)
    }

    @ViewBuilder
    private var videoAnalysisIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text("添付動画を解析中...")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.leading, 40)
    }

    @ViewBuilder
    private func templatePreview(_ template: TemplateDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("提案されたテンプレート")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            TemplatePreviewCard(template: template) {
                viewModel.selectTemplate(template)
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func bgmPreview(_ bgm: BGMTrack) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("提案されたBGM")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            BGMPreviewCard(
                bgm: bgm,
                isSelected: viewModel.selectedBGM?.id == bgm.id
            ) {
                viewModel.selectBGM(bgm)
            }
            .padding(.horizontal)
        }
    }

    private func scrollToBottom() {
        withAnimation {
            scrollProxy?.scrollTo("bottom", anchor: .bottom)
        }
    }

    private func confirmTemplate() {
        guard let template = viewModel.selectedTemplate else { return }
        onTemplateConfirmed(template, viewModel.selectedBGM)
        dismiss()
    }

    private func handleVideoSelection(_ item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mp4")
                try? data.write(to: tempURL)
                viewModel.attachVideo(tempURL)
            }
        }
    }
}

#Preview {
    let container = DIContainer.preview
    let viewModel = ChatViewModel(
        sendMessageUseCase: SendMessageWithAIUseCase(repository: container.geminiRepository),
        fetchTemplatesUseCase: FetchTemplatesUseCase(repository: container.templateRepository),
        analyzeVideoUseCase: AnalyzeVideoUseCase(repository: container.geminiRepository),
        syncChatHistoryUseCase: SyncChatHistoryUseCase(),
        initializeChatSessionUseCase: InitializeChatSessionUseCase()
    )
    return ChatView(viewModel: viewModel) { _, _ in }
}
