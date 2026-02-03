# Chat Feature

## 概要
AIとの会話でVlogのテンプレート・コンセプトを決定する画面。フルスクリーンモーダルで表示。
会話するAIはエージェンティックにユーザーから必要な情報を引き出し、テンプレートを作成する。

## 状態（ViewModel）

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| messages | [ChatMessage] | チャット履歴 |
| inputText | String | 入力中のテキスト |
| isLoading | Bool | AI応答待ち状態 |
| errorMessage | String? | エラーメッセージ |
| quickReplies | [String] | クイック返信選択肢（はい/いいえ等） |
| selectedTemplate | Template? | 選択されたテンプレート |
| selectedBGM | BGMTrack? | 選択されたBGM |
| attachedVideoURL | URL? | 添付された動画のURL |

## ユーザーアクション

1. **テキスト送信** → AIにメッセージ送信
2. **クイック返信ボタンタップ** → 定型文を送信（はい/いいえ等）
3. **動画添付ボタンタップ** → フォトライブラリから動画選択
4. **×ボタンタップ** → モーダルを閉じる
5. **テンプレート確定** → 撮影画面へ遷移

## 遷移先

- RecordingView（テンプレート確定後、モーダルdismiss → 自動遷移）

## UseCase

- `SendMessageUseCase` - Gemini APIにメッセージ送信、応答取得
- `AnalyzeVideoUseCase` - 添付動画をGeminiで解析、セグメントに自動割当
- `FetchTemplatesUseCase` - Firestoreからテンプレート一覧を取得

## コンポーネント

- `ChatBubble` - メッセージバブル（AI/ユーザー）
- `QuickReplyButtons` - クイック返信ボタン群
- `VideoAttachmentButton` - 動画添付ボタン
- `TemplatePreviewCard` - テンプレート提案カード（参考動画サムネイル付き）

## AIチャットの流れ

1. テーマ確認（はい/いいえ）
2. 構成確認（はい/いいえ）
3. テンプレート提案（参考動画付き）
4. 確定確認（はい → 撮影画面へ / いいえ → 深掘り）
5. BGM提案・選択

## 注意点

- 動画添付時、Geminiで解析してテンプレートのセグメントに自動マッピング
- テンプレート確定時にBGMも選択させる
- チャット履歴はProjectに保存される
