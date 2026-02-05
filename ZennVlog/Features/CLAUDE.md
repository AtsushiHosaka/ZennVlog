# View Preview 規約

## 概要

ZennVlogプロジェクトでは、すべてのSwiftUI Viewに対して**必ずPreviewを用意する**ことを必須とします。
Previewはコンポーネント単位でのビジュアル確認を可能にし、開発効率とコード品質を向上させます。

このドキュメントでは、View Previewの実装規約とMockデータの使用方法を定義します。

---

## Preview必須ルール

### 1. すべてのViewにPreviewを用意する

**どんなに小さなViewコンポーネントでも、必ず `#Preview` を用意してください。**

- ボタンひとつのViewでもPreviewを作成
- コンポーネントの動作確認とビジュアルチェックに必須
- 将来の変更時にも即座に影響を確認可能

### 2. Previewの配置場所

**Previewは必ずView structの定義直後、同じファイル内に配置してください。**

```swift
struct ChatBubble: View {
    var body: some View {
        // View実装
    }
}

// ✅ 正しい配置 - View structの直後
#Preview {
    ChatBubble()
}
```

❌ **別ファイルへの分離は禁止**
❌ **ファイル末尾への配置は避ける**

### 3. モダン構文の使用

**iOS 17+の `#Preview` マクロを使用してください。**

```swift
// ✅ 正しい - #Previewマクロ
#Preview {
    SomeView()
}

// ❌ 古い - PreviewProviderは使わない
struct SomeView_Previews: PreviewProvider {
    static var previews: some View {
        SomeView()
    }
}
```

---

## Mockデータの使用

### 基本原則

**Previewで表示するデータは、すべて `/Core/Mock/` ディレクトリのMock実装を使用してください。**

### DIContainer.previewの使用

依存性注入には `DIContainer.preview` を使用します。

**定義場所**: [App/DIContainer.swift:42-44](App/DIContainer.swift#L42-L44)

```swift
// DIContainer.swift
extension DIContainer {
    static var preview: DIContainer {
        DIContainer(useMock: true)
    }
}
```

### Mockの命名規則

すべてのMockは以下の命名規則に従います:

**`Mock[Feature]Repository`**

**例:**
- `MockProjectRepository` - プロジェクトデータのMock
- `MockTemplateRepository` - テンプレートデータのMock
- `MockBGMRepository` - BGMデータのMock
- `MockGeminiRepository` - Gemini APIのMock
- `MockImagenRepository` - Imagen APIのMock

### Mock実装パターン

既存のMock実装では、主に2つのパターンが使われています:

#### パターン1: インスタンスメソッド + インメモリストレージ

**参照**: [Core/Mock/MockProjectRepository.swift](Core/Mock/MockProjectRepository.swift)

```swift
final class MockProjectRepository: ProjectRepositoryProtocol {
    private var projects: [Project] = []

    init() {
        setupMockData()
    }

    private func setupMockData() {
        // Mockデータの初期化
        projects = [
            Project(name: "週末のお出かけVlog", ...),
            Project(name: "カフェ巡りVlog", ...)
        ]
    }
}
```

#### パターン2: 静的ファクトリーメソッド + イミュータブルデータ

**参照**: [Core/Mock/MockTemplateRepository.swift](Core/Mock/MockTemplateRepository.swift)

```swift
final class MockTemplateRepository: TemplateRepositoryProtocol, Sendable {
    private let templates: [TemplateDTO]

    init() {
        templates = Self.createMockTemplates()
    }

    private static func createMockTemplates() -> [TemplateDTO] {
        [
            TemplateDTO(id: "daily-vlog", name: "1日のVlog", ...),
            TemplateDTO(id: "travel-vlog", name: "旅行Vlog", ...),
            TemplateDTO(id: "cooking-vlog", name: "料理Vlog", ...)
        ]
    }
}
```

### Mock URLとネットワーク遅延

- **Mock URL**: プレースホルダーリソースには `mock://` スキームを使用
  ```swift
  VideoAsset(segmentOrder: 0, localFileURL: "mock://video1.mp4", duration: 5)
  ```

- **ネットワーク遅延シミュレーション**: すべてのMockは現実的な遅延(300ms〜2秒)を含む
  ```swift
  private func simulateNetworkDelay() async throws {
      try await Task.sleep(nanoseconds: 300_000_000)  // 300ms
  }
  ```

---

## Previewの実装パターン

### パターン1: 依存関係のないシンプルなView

```swift
import SwiftUI

struct ChatBubble: View {
    let message: String
    let isUser: Bool

    var body: some View {
        HStack {
            if isUser { Spacer() }
            Text(message)
                .padding()
                .background(isUser ? Color.blue : Color.gray.opacity(0.2))
                .cornerRadius(12)
            if !isUser { Spacer() }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ChatBubble(message: "こんにちは!", isUser: true)
        ChatBubble(message: "Vlogのテンプレート作成を手伝います", isUser: false)
    }
    .padding()
}
```

### パターン2: ViewModelや依存関係を持つView

```swift
import SwiftUI

struct ProjectListView: View {
    @StateObject var viewModel: ProjectListViewModel

    var body: some View {
        List(viewModel.projects) { project in
            ProjectCard(project: project)
        }
        .task {
            await viewModel.loadProjects()
        }
    }
}

#Preview {
    let container = DIContainer.preview
    let viewModel = ProjectListViewModel(
        repository: container.projectRepository
    )
    return ProjectListView(viewModel: viewModel)
}
```

### パターン3: Environment Objectsを使うView

```swift
import SwiftUI

struct TemplatePreviewCard: View {
    let template: TemplateDTO
    @EnvironmentObject var container: DIContainer

    var body: some View {
        VStack(alignment: .leading) {
            Text(template.name)
                .font(.headline)
            Text(template.description)
                .font(.caption)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    TemplatePreviewCard(
        template: TemplateDTO(
            id: "daily-vlog",
            name: "1日のVlog",
            description: "朝から夜までの1日を記録するテンプレート",
            referenceVideoUrl: "https://youtube.com/example1",
            explanation: "朝→昼→夜の流れで、日常の何気ない瞬間を切り取ります",
            segments: []
        )
    )
    .environmentObject(DIContainer.preview)
}
```

### パターン4: 複数の状態バリエーションを表示

```swift
import SwiftUI

struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                .font(.system(size: 64))
                .foregroundColor(isRecording ? .red : .white)
        }
    }
}

#Preview("録画中") {
    RecordButton(isRecording: true, action: {})
        .preferredColorScheme(.dark)
}

#Preview("待機中") {
    RecordButton(isRecording: false, action: {})
        .preferredColorScheme(.dark)
}
```

---

## Mock実装の参照

### 既存のMockリポジトリ一覧

新しいViewのPreviewを作成する際は、以下のMock実装を参照してください:

| Mock | ファイルパス | 用途 |
|------|------------|------|
| MockProjectRepository | [Core/Mock/MockProjectRepository.swift](Core/Mock/MockProjectRepository.swift) | プロジェクトデータ (週末のお出かけVlog、カフェ巡りVlogなど) |
| MockTemplateRepository | [Core/Mock/MockTemplateRepository.swift](Core/Mock/MockTemplateRepository.swift) | テンプレートデータ (1日のVlog、旅行Vlog、料理Vlogなど) |
| MockBGMRepository | [Core/Mock/MockBGMRepository.swift](Core/Mock/MockBGMRepository.swift) | BGMトラック (爽やかな朝、チルな午後など) |
| MockGeminiRepository | [Core/Mock/MockGeminiRepository.swift](Core/Mock/MockGeminiRepository.swift) | Gemini API応答 (会話フロー、動画分析結果) |
| MockImagenRepository | [Core/Mock/MockImagenRepository.swift](Core/Mock/MockImagenRepository.swift) | 画像生成 (プレースホルダー画像) |

### Mockデータの特徴

- **日本語コンテンツ**: すべてのMockデータは日本語で記述されています
- **リッチなデータ**: 現実的な使用シナリオを想定した詳細なデータ
- **ネットワーク遅延**: `simulateNetworkDelay()` で300ms〜2秒の遅延をシミュレート
- **Sendable準拠**: Swift並行性に対応するため、ほとんどのMockが `Sendable` に準拠

### 新しいMockを作成する場合

新しい機能のMockが必要な場合は、以下のガイドラインに従ってください:

1. **配置場所**: `/Core/Mock/` ディレクトリ
2. **命名**: `Mock[Feature]Repository.swift`
3. **プロトコル実装**: 対応する `[Feature]RepositoryProtocol` を実装
4. **Sendable準拠**: 可能な限り `Sendable` に準拠
5. **ネットワーク遅延**: `simulateNetworkDelay()` メソッドを含める
6. **リッチなデータ**: 現実的な日本語Mockデータを用意

---

## 技術制約と要件

### 必須要件

- **iOS 17+**: `#Preview` マクロを使用するため
- **Swift 5.9+**: `#Preview` マクロのサポート
- **Sendable準拠**: Swift並行性のため、Mockは `Sendable` に準拠することを推奨

### Previewの動作環境

- **Xcode Canvas**: リアルタイムプレビュー
- **Xcode Simulator**: デバイスシミュレーターでの実行
- **実機プレビュー**: Xcode 15+で実機上でのプレビュー可能

### Mock URLスキーム

プレースホルダーリソースには `mock://` URLスキームを使用:

```swift
// 動画ファイルのMock URL
VideoAsset(segmentOrder: 0, localFileURL: "mock://video1.mp4", duration: 5)

// BGMファイルのMock URL
BGMTrack(id: "1", title: "爽やかな朝", downloadURL: "mock://bgm/morning.mp3")
```

### ネットワーク遅延シミュレーション

現実的なAPI動作をシミュレートするため、Mockは以下の遅延時間を使用します:

```swift
// 標準的な遅延 (300ms)
private func simulateNetworkDelay() async throws {
    try await Task.sleep(nanoseconds: 300_000_000)
}

// 長い遅延 (2秒)
private func simulateLongNetworkDelay() async throws {
    try await Task.sleep(nanoseconds: 2_000_000_000)
}
```

---

## まとめ

### Previewチェックリスト

新しいViewを作成したら、以下を必ず確認してください:

- [ ] `#Preview` が View structの直後に配置されている
- [ ] Mockデータを使用している (実データやハードコードされた値は使わない)
- [ ] `DIContainer.preview` を使用して依存性注入している
- [ ] 複数の状態バリエーションがある場合は、それぞれPreviewを用意
- [ ] Xcodeのキャンバスで正常に表示されることを確認

### 参考リンク

- **現在の実装例**: [ContentView.swift:22-24](ZennVlog/ZennVlog/ContentView.swift#L22-L24)
- **DIContainer**: [App/DIContainer.swift](App/DIContainer.swift)
- **Mock実装例**: [Core/Mock/](Core/Mock/)
