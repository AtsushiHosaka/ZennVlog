import SwiftUI

/// 撮影ボタン（進捗表示付き）
/// 円周上に現在のセグメント長さに対する進捗を表示
struct RecordButtonWithProgress: View {
    let isRecording: Bool
    let progress: Double
    let canRecord: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            ZStack {
                // 進捗円（グレー背景）
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                    .frame(width: 80, height: 80)

                // 進捗円（青）
                Circle()
                    .trim(from: 0, to: min(progress, 1.0))
                    .stroke(Color.accentColor, lineWidth: 4)
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: progress)

                // 撮影ボタン本体
                Circle()
                    .fill(isRecording ? Color.white : (canRecord ? Color.red : Color.gray))
                    .frame(width: 60, height: 60)
                    .overlay {
                        if isRecording {
                            // 停止アイコン
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.red)
                                .frame(width: 20, height: 20)
                        }
                    }
            }
        }
        .disabled(!canRecord && !isRecording)
    }
}

#Preview("待機中") {
    RecordButtonWithProgress(
        isRecording: false,
        progress: 0,
        canRecord: true,
        onTap: {}
    )
    .padding()
    .background(Color.black)
}

#Preview("撮影中") {
    RecordButtonWithProgress(
        isRecording: true,
        progress: 0.6,
        canRecord: true,
        onTap: {}
    )
    .padding()
    .background(Color.black)
}

#Preview("撮影不可") {
    RecordButtonWithProgress(
        isRecording: false,
        progress: 0,
        canRecord: false,
        onTap: {}
    )
    .padding()
    .background(Color.black)
}

#Preview("進捗100%") {
    RecordButtonWithProgress(
        isRecording: true,
        progress: 1.0,
        canRecord: true,
        onTap: {}
    )
    .padding()
    .background(Color.black)
}
