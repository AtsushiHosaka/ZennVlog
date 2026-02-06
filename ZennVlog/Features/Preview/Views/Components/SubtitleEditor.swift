import SwiftUI

/// テロップ入力エディタ
/// セグメントごとにテロップを編集
struct SubtitleEditor: View {
    let segmentIndex: Int
    @Binding var subtitleText: String
    let onSave: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("セグメント \(segmentIndex + 1) のテロップ")
                .font(.headline)

            HStack {
                TextField("テロップを入力", text: $subtitleText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                    .focused($isFocused)

                Button {
                    onSave()
                    isFocused = false
                } label: {
                    Text("保存")
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .disabled(subtitleText.isEmpty)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview("空状態") {
    SubtitleEditor(
        segmentIndex: 0,
        subtitleText: .constant(""),
        onSave: {}
    )
    .padding()
}

#Preview("入力中") {
    SubtitleEditor(
        segmentIndex: 2,
        subtitleText: .constant("朝の散歩シーン"),
        onSave: {}
    )
    .padding()
}

#Preview("長いテキスト") {
    SubtitleEditor(
        segmentIndex: 1,
        subtitleText: .constant("これは長いテロップのサンプルです。複数行にわたる場合もあります。"),
        onSave: {}
    )
    .padding()
}
