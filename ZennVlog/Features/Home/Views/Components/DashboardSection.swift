import SwiftUI

/// 汎用ダッシュボードセクション
/// 追加・削除・並び替えが容易なセクションコンポーネント
struct DashboardSection<Item: Identifiable, Content: View>: View {
    let title: String
    let items: [Item]
    let emptyMessage: String
    let showAllAction: (() -> Void)?
    @ViewBuilder let content: (Item) -> Content

    init(
        title: String,
        items: [Item],
        emptyMessage: String = "項目がありません",
        showAllAction: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.title = title
        self.items = items
        self.emptyMessage = emptyMessage
        self.showAllAction = showAllAction
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ヘッダー
            HStack {
                Text(title)
                    .font(.headline)

                Spacer()

                if let action = showAllAction, !items.isEmpty {
                    Button("すべて見る") {
                        action()
                    }
                    .font(.caption)
                }
            }

            // コンテンツ
            if items.isEmpty {
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(items) { item in
                    content(item)
                }
            }
        }
    }
}

#Preview("アイテムあり") {
    struct SampleItem: Identifiable {
        let id = UUID()
        let name: String
    }

    let items = [
        SampleItem(name: "アイテム1"),
        SampleItem(name: "アイテム2"),
        SampleItem(name: "アイテム3")
    ]

    return DashboardSection(
        title: "サンプルセクション",
        items: items,
        showAllAction: {}
    ) { item in
        Text(item.name)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
    }
    .padding()
}

#Preview("空状態") {
    struct SampleItem: Identifiable {
        let id = UUID()
        let name: String
    }

    return DashboardSection(
        title: "空のセクション",
        items: [SampleItem](),
        emptyMessage: "まだ項目がありません"
    ) { item in
        Text(item.name)
    }
    .padding()
}
