# Recording Feature

## 概要
テンプレートに沿って動画素材を撮影・追加していく画面。Premiere Proのようなタイムライン表示。

## 状態（ViewModel）

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| project | Project | 現在のプロジェクト |
| segments | [Segment] | テンプレートのセグメント一覧 |
| videoAssets | [VideoAsset] | セグメントに割り当てられた動画素材 |
| stockVideoAssets | [VideoAsset] | ストック動画素材（segmentOrder: nil） |
| currentSegmentIndex | Int | 現在選択中のセグメントインデックス |
| isRecording | Bool | 撮影中フラグ |
| recordingDuration | Double | 現在の撮影時間（秒） |
| guideImage | UIImage? | 撮影ガイド画像（Gemini API生成） |
| isLoadingGuideImage | Bool | ガイド画像生成中 |
| showGuideImage | Bool | ガイド画像表示フラグ |
| errorMessage | String? | エラーメッセージ |
| canProceedToPreview | Bool | 全素材揃っているか |
| showTrimEditor | Bool | トリム編集画面表示フラグ |
| videoToTrim | URL? | トリム対象の動画URL |
| videoScenes | [(timestamp: Double, description: String)] | Gemini API動画要約結果 |

## ユーザーアクション

1. **撮影ボタンタップ** → 動画撮影開始/停止（最初の空白セグメントのみ可能）
2. **タイムラインのセグメントをタップ** → フォトライブラリから動画追加、Gemini API動画要約後にトリム編集画面へ
3. **セグメント長押し** → 削除メニュー表示（撮影済みセグメントのみ）
4. **ストック動画タップ** → セグメント選択ダイアログ表示、割り当て先を選択
5. **ストック動画長押し** → 削除メニュー表示
6. **ガイド表示/非表示トグル** → 撮影ガイド画像の表示/非表示切り替え
7. **[<]ボタン** → ホーム画面に戻る
8. **[編集]ボタン** → プレビュー画面へ遷移（全素材完了時のみ有効）

## 遷移先

- HomeView（戻る）
- PreviewView（全素材撮影完了後）

## UseCase

- `SaveVideoAssetUseCase` - 撮影/選択した動画をプロジェクトに保存（segmentOrderを指定、またはstockVideoAssetsに追加）
- `GenerateGuideImageUseCase` - Gemini APIで撮影ガイド画像を生成（Imagen APIから変更）
- `AnalyzeVideoUseCase` - Gemini APIで動画を分析し、タイムスタンプ付きシーン説明リストを取得
- `TrimVideoUseCase` - AVAssetExportSessionで動画をトリム（開始・終了時刻を指定）
- `DeleteVideoAssetUseCase` - セグメントまたはストックから動画素材を削除

## コンポーネント

- `CameraPreview` - カメラプレビュー表示（AVCaptureSession使用）
- `TimelineView` - Premiere Proライクタイムライン（横スクロール、セグメント幅が動画長に比例）
- `SegmentCard` - セグメントカード（サムネイル or プレースホルダー、タップでライブラリから追加、長押しで削除）
- `StockVideoArea` - ストック動画表示エリア（タイムライン下、横スクロール）
- `StockVideoCard` - ストック動画カード（タップで割り当て先選択、長押しで削除）
- `GuideImageView` - 撮影ガイド画像表示（Gemini API生成、半透明オーバーレイ）
- `SegmentDescriptionOverlay` - セグメント説明文オーバーレイ（カメラプレビュー上部）
- `RecordButtonWithProgress` - 撮影ボタン（円周上に現在のセグメント進捗表示）
- `TrimEditorView` - トリム編集画面（動画プレビュー、シーン説明リスト、トリムスライダー）

## タイムライン仕様（Premiere Proライク）

- **セグメント幅**: 動画の長さに比例（totalDuration基準で計算）
- **撮影済み**: サムネイル + ✓マーク（緑）
- **未撮影**: グレーのプレースホルダー + セグメント名
- **現在選択中**: 青い枠線、背景色ハイライト
- **タップ動作**: フォトライブラリから動画追加、Gemini API動画要約後にトリム編集
- **長押し**: 削除メニュー（撮影済みセグメントのみ）
- **タイムコード**: セグメント下に表示（MM:SS形式）

---

## エンティティ設計とデータモデル

### Project拡張
- `stockVideoAssets: [VideoAsset]` - ストック動画（segmentOrder: nil）を管理

### VideoAsset拡張
- `segmentOrder: Int?` - nil の場合はストック動画
- `trimStartSeconds: Double` - トリム開始時刻（秒、デフォルト0.0）
- `trimEndSeconds: Double` - トリム終了時刻（秒、デフォルト0.0）

### Project - Segment - VideoAsset の関係
- Project.template.segments: テンプレートのセグメント一覧（order: 0, 1, 2, ...）
- Project.videoAssets: セグメントに割り当てられた素材（segmentOrder != nil）
- Project.stockVideoAssets: ストック素材（segmentOrder == nil）
- **1対1対応**: 各セグメントに対して VideoAsset は最大1個
- **重複時**: 同じ segmentOrder の VideoAsset を追加 → 既存を上書き

---

## 撮影制約ロジック

### 撮影可能条件
最初の空白セグメントのみ撮影可能。

```swift
func canRecord(for segmentOrder: Int) -> Bool {
    guard let firstEmptySegment = firstEmptySegmentOrder() else {
        return false // 全て埋まっている
    }
    return segmentOrder == firstEmptySegment
}

func firstEmptySegmentOrder() -> Int? {
    return (0..<segments.count).first { order in
        !videoAssets.contains { $0.segmentOrder == order }
    }
}
```

### ストック動画への保存
空白セグメント以外を選択して撮影した場合、ストックとして保存。

```swift
func saveAsStock(_ asset: VideoAsset) {
    var stockAsset = asset
    stockAsset.segmentOrder = nil
    project.stockVideoAssets.append(stockAsset)
}
```

---

## タイムライン表示ロジック（Premiere Proライク）

### 比例幅の計算
```swift
func segmentWidth(for segment: Segment) -> CGFloat {
    let totalDuration = segments.reduce(0) { $0 + ($1.endSeconds - $1.startSeconds) }
    let segmentDuration = segment.endSeconds - segment.startSeconds
    let screenWidth = UIScreen.main.bounds.width - 32
    return screenWidth * (segmentDuration / totalDuration)
}
```

### TimelineView構成
```swift
HStack(spacing: 0) {
    ForEach(segments) { segment in
        SegmentCard(segment: segment, width: segmentWidth(for: segment))
            .onTapGesture {
                showLibraryPicker(for: segment.order)
            }
            .contextMenu {
                if isSegmentRecorded(segment.order) {
                    Button("削除", role: .destructive) {
                        deleteVideoAsset(for: segment.order)
                    }
                }
            }
    }
}
```

---

## ストック動画管理

### ストック動画表示エリア
タイムラインの下に別領域で表示。

```swift
VStack {
    TimelineView(...)

    Divider()

    ScrollView(.horizontal) {
        HStack {
            ForEach(stockVideoAssets) { asset in
                StockVideoCard(asset: asset)
                    .onTapGesture {
                        showSegmentSelector(for: asset)
                    }
                    .contextMenu {
                        Button("削除", role: .destructive) {
                            deleteStockAsset(asset)
                        }
                    }
            }
        }
    }
    .frame(height: 80)
}
```

---

## 動画トリム機能（Gemini API統合）

### フォトライブラリから選択後の流れ
```
ライブラリから動画選択
  ↓
AnalyzeVideoUseCase.execute(videoURL) → Gemini API
  ↓
Gemini API: タイムスタンプ + シーン説明リスト
  ↓
TrimEditorView表示
  ↓
ユーザーがトリム範囲設定
  ↓
TrimVideoUseCase.execute(videoURL, startSeconds, endSeconds)
  ↓
VideoAsset作成（trimStartSeconds, trimEndSeconds設定）
  ↓
SaveVideoAssetUseCase
```

### Gemini API動画要約
**使用API**: Gemini 1.5 Pro（動画理解機能）
**エンドポイント**: `models/gemini-1.5-pro:generateContent`

**リクエスト**:
```json
{
  "contents": [{
    "parts": [
      {"video": {"uri": "gs://bucket/video.mp4"}},
      {"text": "Describe what happens in this video at different timestamps. Return a list of timestamps (MM:SS format) with scene descriptions."}
    ]
  }]
}
```

**レスポンス例**:
```json
{
  "candidates": [{
    "content": {
      "parts": [{
        "text": "00:00 - Opening scene\n00:15 - Person walking\n00:45 - Close-up\n01:20 - Ending"
      }]
    }
  }]
}
```

**パース処理**:
- テキストを行ごとに分割
- タイムスタンプ（MM:SS）とシーン説明を抽出
- タイムスタンプをDouble（秒）に変換
- `[(timestamp: Double, description: String)]` 配列を作成

### TrimEditorView仕様
- **上部**: 動画プレビュー（AVPlayer使用）
- **中央**: シーン説明リスト（Geminiから取得）
- **下部**: トリムスライダー（開始・終了ハンドル付き）
- **ボタン**: 確定、キャンセル

---

## 撮影ガイド画像生成（Gemini API）

### API変更
- **旧**: Imagen API
- **新**: Gemini API（画像生成機能、Imagen 3統合）

### 生成フロー
```
セグメント選択
  ↓
GenerateGuideImageUseCase.execute(prompt: segment.segmentDescription)
  ↓
GeminiRepository.generateImage(prompt)
  ↓
Gemini API: 画像生成
  ↓
guideImage = UIImage
  ↓
キャッシュに保存（[Int: UIImage]、最大5個）
```

---

## UI/UX詳細設計

### 画面レイアウト
```
VStack {
    // 上部: タイムライン（Premiere Proライク）
    ScrollView(.horizontal) {
        TimelineView(segments, videoAssets)
    }
    .frame(height: 120)

    // 中央: カメラプレビュー + ガイド + 説明文
    ZStack {
        CameraPreview()

        // 説明文章オーバーレイ（上部）
        if let currentSegment = segments[safe: currentSegmentIndex] {
            Text(currentSegment.segmentDescription)
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
                .padding(.top, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }

        // ガイド画像オーバーレイ（半透明）
        if showGuideImage, let guideImage = guideImage {
            Image(uiImage: guideImage)
                .opacity(0.5)
        }

        if isLoadingGuideImage {
            ProgressView()
        }
    }

    // 下部: ストック動画エリア
    StockVideoArea(stockVideoAssets)

    // 最下部: 撮影ボタン
    RecordButtonWithProgress(
        currentSegment: currentSegment,
        recordingDuration: recordingDuration
    )
}
```

### RecordButtonWithProgress
撮影ボタンの円周上に現在のセグメント長さに対する進捗を表示。

```swift
struct RecordButtonWithProgress: View {
    let currentSegment: Segment
    let recordingDuration: Double

    var progress: Double {
        let segmentDuration = currentSegment.endSeconds - currentSegment.startSeconds
        return min(recordingDuration / segmentDuration, 1.0)
    }

    var body: some View {
        ZStack {
            // 進捗円（グレー背景）
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                .frame(width: 80, height: 80)

            // 進捗円（青）
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.blue, lineWidth: 4)
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(-90))

            // 撮影ボタン
            Circle()
                .fill(isRecording ? Color.white : Color.red)
                .frame(width: 60, height: 60)
                .overlay {
                    if isRecording {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red)
                            .frame(width: 20, height: 20)
                    }
                }
        }
    }
}
```

---

## データフロー

Chat → Template選択 → Project.template設定、status = .recording → Recording画面 → セグメント選択 → 撮影 or ライブラリから選択 → 動画要約（Gemini API） → トリム編集 → SaveVideoAssetUseCase → Project.videoAssets更新 → SwiftUI再描画 → 全素材完了 → Preview画面

---

## エラーハンドリング

- **カメラ権限なし**: 権限リクエストダイアログ、拒否時は設定画面誘導
- **ライブラリ権限なし**: 権限リクエストダイアログ、拒否時は設定画面誘導
- **ガイド画像生成失敗（Gemini API）**: エラーメッセージ表示、リトライボタン
- **動画保存失敗**: エラーメッセージ表示、再撮影促す
- **テンプレート未設定**: Chat画面へ誘導
- **動画分析失敗（Gemini API）**: エラーメッセージ表示、トリム機能スキップ可能
- **トリム失敗**: エラーメッセージ表示、元の動画を使用

---

## 注意点

- 撮影ガイド画像はGemini APIで生成（Imagen APIから変更）
- カメラプレビューとガイド画像は半透明で重ねて表示（showGuideImageで制御）
- 説明文章はカメラプレビュー上部にオーバーレイ表示
- 全セグメント撮影完了で[編集]ボタンが有効化
- カメラ/マイクの権限リクエストが必要
- Gemini API制約: 動画サイズ制限、処理時間（1.5秒程度）
- タイムラインはPremiere Proライクに動画長に比例した幅で表示
- ストック動画はタイムラインの下に別領域で表示
- 撮影は最初の空白セグメントに対してのみ可能
