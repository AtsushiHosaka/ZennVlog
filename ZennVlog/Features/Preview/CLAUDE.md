# Preview Feature

## 概要
全素材が揃った後、テロップやBGMを追加して最終調整する画面。

## 状態（ViewModel）

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| project | Project | 現在のプロジェクト |
| isPlaying | Bool | 再生中フラグ |
| currentTime | Double | 現在の再生位置（秒） |
| duration | Double | 動画の総時間（秒） |
| currentSegmentIndex | Int | 現在のセグメントインデックス |
| subtitleText | String | 編集中のテロップテキスト |
| selectedBGM | BGMTrack? | 選択中のBGM |
| bgmTracks | [BGMTrack] | BGM一覧 |
| showBGMSelector | Bool | BGM選択モーダル表示フラグ |
| isExporting | Bool | 書き出し中フラグ |
| errorMessage | String? | エラーメッセージ |

## ユーザーアクション

1. **再生/一時停止ボタン** → 動画の再生制御
2. **タイムラインのセグメントをタップ** → そのセグメントにシーク
3. **テロップ入力** → 選択中セグメントにテロップを設定
4. **BGM[変更]ボタン** → BGM選択モーダルを表示
5. **BGM選択** → BGMを変更
6. **[<]ボタン** → 撮影画面に戻る
7. **[共有]ボタン** → シェア画面へ遷移

## 遷移先

- RecordingView（戻る）
- ShareView（共有ボタン）

## UseCase

- `FetchBGMTracksUseCase` - FirestoreからBGM一覧を取得
- `ExportVideoUseCase` - 動画 + テロップ + BGMを合成して書き出し

## コンポーネント

- `VideoPlayerView` - 動画プレーヤー（テロップオーバーレイ付き）
- `SubtitleOverlay` - テロップ表示レイヤー
- `SubtitleEditor` - テロップ入力欄
- `BGMSelector` - BGM選択モーダル（試聴機能付き）
- `PreviewTimeline` - セグメント選択用タイムライン

## 注意点

- テロップはセグメントごとに設定
- BGMはチャット時点で選択済みだが、ここで変更可能
- 書き出しはNextLevelSessionExporterを使用
- 書き出し完了後にShareViewへ遷移
