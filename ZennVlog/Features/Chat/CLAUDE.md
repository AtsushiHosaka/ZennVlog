# Chat Feature

## 概要
AIとの会話でVlogのテンプレート・コンセプトを決定する画面。フルスクリーンモーダルで表示。
会話するAIはエージェンティックにユーザーから必要な情報を引き出し、テンプレートを作成する。

**技術スタック**: Gemini APIを使用。Function Callingにより、テンプレート検索・BGM選択は実際のリポジトリからデータを取得して応答する。

## 状態（ViewModel）

### 基本状態

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| messages | [ChatMessage] | チャット履歴（SwiftData） |
| inputText | String | 入力中のテキスト |
| isLoading | Bool | AI応答待ち状態 |
| errorMessage | String? | エラーメッセージ |
| quickReplies | [String] | クイック返信選択肢（はい/いいえ等） |
| selectedTemplate | Template? | 選択されたテンプレート |
| selectedBGM | BGMTrack? | 選択されたBGM |
| attachedVideoURL | URL? | 添付された動画のURL |

### Agentic機能用の追加状態

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| streamingText | String | ストリーミング中のテキスト（徐々に追加） |
| toolExecutionStatus | ToolExecutionStatus? | ツール実行状態（ツール名、実行中/完了、結果） |
| thinkingSteps | [ThinkingStep] | 思考プロセスステップ（推論、分析、計画、結論） |
| showTemplatePreview | Bool | テンプレートプレビュー表示フラグ |
| previewTemplates | [TemplateDTO] | プレビュー対象テンプレート一覧 |

## ユーザーアクション

1. **テキスト送信** → AIにメッセージ送信
2. **クイック返信ボタンタップ** → 定型文を送信（はい/いいえ等）
3. **動画添付ボタンタップ** → フォトライブラリから動画選択
4. **×ボタンタップ** → モーダルを閉じる
5. **テンプレート確定** → 撮影画面へ遷移

## 遷移先

- RecordingView（テンプレート確定後、モーダルdismiss → 自動遷移）

## UseCase

- `InitializeChatSessionUseCase` - チャットセッションの初期化または復元
- `SendMessageWithAIUseCase` - Gemini APIへメッセージ送信、Function Callingループによるツール実行オーケストレーション
- `SyncChatHistoryUseCase` - SwiftDataのChatMessageの同期
- `AnalyzeVideoUseCase` - 添付動画をGeminiで解析、セグメントに自動割当（videoAnalysisツールから呼び出される）
- `FetchTemplatesUseCase` - Firestoreからテンプレート一覧を取得（templateSearchツールから呼び出される）

## コンポーネント

- `ChatBubble` - メッセージバブル（AI/ユーザー）
- `StreamingMessageBubble` - ストリーミング用メッセージバブル（カーソル点滅アニメーション）
- `ToolExecutionIndicator` - ツール実行中インジケータ（「テンプレートを検索中...」など）
- `ThinkingProcessView` - 思考プロセス可視化ビュー（タイムライン形式、アイコン付き）
- `TemplatePreviewCard` - テンプレート提案カード（参考動画サムネイル16:9、詳細情報、選択ボタン）
- `QuickReplyButtons` - クイック返信ボタン群
- `VideoAttachmentButton` - 動画添付ボタン

## AIチャットの流れ

1. テーマ確認（はい/いいえ）
2. 構成確認（はい/いいえ）
3. テンプレート提案（参考動画付き）
4. 確定確認（はい → 撮影画面へ / いいえ → 深掘り）
5. BGM提案・選択

## 注意点

- 動画添付時、Geminiで解析してテンプレートのセグメントに自動マッピング
- テンプレート確定時にBGMも選択させる
- チャット履歴はProjectに保存される（SwiftData）

---

## Gemini Function Calling 統合設計

### データフロー

User Input → ChatViewModel.sendMessage() → SendMessageWithAIUseCase (Function Calling Loop) → GeminiRepository → GeminiRESTDataSource → Gemini API応答（text or functionCall） → ツール実行（テンプレート検索/動画分析/BGM選択） → 結果をcontentsに追加 → 再度Gemini API呼び出し → 最終テキスト応答 → JSONパースして GeminiChatResponse → ViewModel更新 → SwiftUI描画 → SwiftData保存

### Function Calling ループ

1. history + 新メッセージから contents を構築
2. `repository.sendTurn()` を tool declarations 付きで呼び出し
3. `.functionCall` なら → ツール実行 → 結果をcontentsに追加 → 再度呼び出し
4. `.text` なら → JSONパースして `GeminiChatResponse` を返す
5. 最大5回のイテレーションガード

### Tools定義（Gemini Function Calling 形式）

#### 1. templateSearch
ユーザーの希望に合うVlogテンプレートを検索。TemplateRepositoryから取得し、クエリとカテゴリでフィルタリング。

**パラメータ**: query（String）、category（String, optional）

#### 2. videoAnalysis
添付動画を解析し、セグメントに自動マッピング。GeminiRepository.analyzeVideo()を呼び出し。

**パラメータ**: videoURL（String）

#### 3. bgmSelection
テンプレートに合うBGMを提案。BGMRepositoryから取得し、テンプレート名とmoodでフィルタ、上位3件を推薦。

**パラメータ**: templateId（String）、mood（String, optional）

---

## Agentic機能の詳細

### マルチステップ推論

AIの思考プロセスを段階的に表示。ThinkingStepType: reasoning（推論中）、analyzing（分析中）、planning（計画中）、concluding（結論中）。ThinkingProcessViewでタイムライン形式表示、紫背景で強調。

### プロアクティブな質問生成

システムプロンプトで指示し、AIが自律的に質問を生成。会話フェーズ（初期→詳細化→提案→確認→BGM選択）に応じて適切な質問をする。

---

## UI/UX詳細設計

### ストリーミング表示

StreamingMessageBubble: テキストが徐々に追加される（ChatGPTライク）、カーソル点滅アニメーション。streamResponseメソッドで単語ごとに0.05秒間隔で表示。

### ツール実行インジケータ

ToolExecutionIndicator: ツール名に応じた表示（「テンプレートを検索中...」「動画を分析中...」「BGMを選択中...」）。実行中はProgressView、完了時はチェックマーク。

### 思考プロセス可視化

ThinkingProcessView: タイムライン形式で各ステップを表示（推論、分析、計画、結論）。紫背景、フェードインアニメーション。

### テンプレートプレビューカード

TemplatePreviewCard: 参考動画サムネイル（16:9）、テンプレート名、説明、「このテンプレートを使う」ボタン。カード型UI（角丸、影付き）。

---

## エラーハンドリング

**ChatError**: toolExecutionFailed、streamingInterrupted、invalidToolParameters、networkUnavailable

**主要ケース**:
- ネットワーク不可: Gemini APIはネットワーク必須のためエラーメッセージ表示
- ツール実行失敗: エラーメッセージ表示、会話継続
