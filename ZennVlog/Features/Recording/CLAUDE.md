# Recording Feature

## 概要
テンプレートに沿って動画素材を撮影・追加していく画面。Premiere Proのようなタイムライン表示。

## 状態（ViewModel）

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| project | Project | 現在のプロジェクト |
| segments | [Segment] | テンプレートのセグメント一覧 |
| videoAssets | [VideoAsset] | 登録済み動画素材 |
| currentSegmentIndex | Int | 現在選択中のセグメントインデックス |
| isRecording | Bool | 撮影中フラグ |
| guideImage | UIImage? | 撮影ガイド画像（Imagen生成） |
| isLoadingGuideImage | Bool | ガイド画像生成中 |
| errorMessage | String? | エラーメッセージ |
| canProceedToPreview | Bool | 全素材揃っているか |

## ユーザーアクション

1. **撮影ボタンタップ** → 動画撮影開始/停止
2. **ライブラリから選択** → フォトライブラリから動画追加
3. **タイムラインのセグメントをタップ** → そのセグメントを選択
4. **[<]ボタン** → ホーム画面に戻る
5. **[編集]ボタン** → プレビュー画面へ遷移（全素材完了時のみ有効）

## 遷移先

- HomeView（戻る）
- PreviewView（全素材撮影完了後）

## UseCase

- `SaveVideoAssetUseCase` - 撮影/選択した動画をプロジェクトに保存
- `GenerateGuideImageUseCase` - Imagen APIで撮影ガイド画像を生成

## コンポーネント

- `CameraPreview` - カメラプレビュー表示
- `TimelineView` - 横スクロール可能なタイムライン（セグメントカード群）
- `SegmentCard` - 各セグメントのカード（サムネイル or プレースホルダー）
- `GuideImageView` - 撮影ガイド画像表示
- `RecordButton` - 撮影ボタン

## タイムライン仕様

- セグメントが横並びで表示
- 撮影済み: サムネイル + ✓マーク
- 未撮影: プレースホルダー + セグメント名
- 現在選択中: ハイライト表示
- 下部にタイムコード表示（0:00, 0:05, 0:15...）

## 注意点

- 撮影ガイド画像はセグメントの説明文からImagen APIで生成
- カメラプレビューとガイド画像は切り替え可能
- 全セグメント撮影完了で[編集]ボタンが有効化
- カメラ/マイクの権限リクエストが必要
