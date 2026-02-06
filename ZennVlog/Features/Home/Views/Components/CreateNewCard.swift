import SwiftUI

/// つくりたいものカード（iMessageライクなTextField）
struct CreateNewCard: View {
    @Binding var inputText: String
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("新しいVlogを作る")
                .font(.headline)

            HStack {
                TextField("何を作りたい？", text: $inputText)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit {
                        if !inputText.isEmpty {
                            onSubmit()
                        }
                    }

                Button {
                    if !inputText.isEmpty {
                        onSubmit()
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(inputText.isEmpty ? .gray : .blue)
                }
                .disabled(inputText.isEmpty)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(20)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

#Preview("空状態") {
    CreateNewCard(inputText: .constant(""), onSubmit: {})
        .padding()
        .background(Color.gray.opacity(0.1))
}

#Preview("入力中") {
    CreateNewCard(inputText: .constant("週末の旅行Vlog"), onSubmit: {})
        .padding()
        .background(Color.gray.opacity(0.1))
}
