# Chat Feature

## 概要
AIとの会話でVlogのテンプレート・コンセプトを決定する画面。フルスクリーンモーダルで表示。
会話するAIはエージェンティックにユーザーから必要な情報を引き出し、テンプレートを作成する。

**技術スタック**: iOS 26のFoundation Models Framework（オンデバイスLLM ~3Bパラメータ）を使用し、プライバシー保護・オフライン対応・コスト削減を実現。オンデバイスモデル利用不可時はGemini APIへ自動フォールバック。

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
| isOffline | Bool | オフライン状態フラグ（ネットワーク監視） |

## ユーザーアクション

1. **テキスト送信** → AIにメッセージ送信
2. **クイック返信ボタンタップ** → 定型文を送信（はい/いいえ等）
3. **動画添付ボタンタップ** → フォトライブラリから動画選択
4. **×ボタンタップ** → モーダルを閉じる
5. **テンプレート確定** → 撮影画面へ遷移

## 遷移先

- RecordingView（テンプレート確定後、モーダルdismiss → 自動遷移）

## UseCase

- `InitializeChatSessionUseCase` - LanguageModelSessionの初期化または復元
- `SendMessageWithAIUseCase` - Foundation Modelsへメッセージ送信、ストリーミング応答取得、ツール呼び出しオーケストレーション
- `SyncChatHistoryUseCase` - SwiftDataのChatMessageとLanguageModelSessionの同期
- `AnalyzeVideoUseCase` - 添付動画をGeminiで解析、セグメントに自動割当（VideoAnalysisToolから呼び出される）
- `FetchTemplatesUseCase` - Firestoreからテンプレート一覧を取得（TemplateSearchToolから呼び出される）

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
- **iOS 26 / A17 Pro以降のiPhone必須**: Foundation Models Framework使用のため
- **地域制限あり**: Foundation Modelsのロールアウト状況により利用可否が異なる
- **オフライン対応**: 会話継続可能（動画分析を除く）

---

## Foundation Models統合設計

### オンデバイスAI実装

#### LanguageModelSession
- iOS 26のFoundation Models Framework使用
- ~3Bパラメータのオンデバイス言語モデル
- Apple Silicon（CPU/GPU/Neural Engine）で高速実行
- プライバシー保護：データは端末外に送信されない
- オフライン対応：ネットワーク不要で動作

#### システムプロンプト設計
Vlogエキスパートアシスタントとしての役割定義：
- ユーザーからテーマ・内容を引き出す
- テンプレート検索（templateSearchツール）、動画分析（videoAnalysisツール）、BGM選択（bgmSelectionツール）を適切に使用
- フレンドリーでプロアクティブな対話スタイル
- 「はい/いいえ」で答えやすい質問形式
- 会話フロー: テーマ確認 → テンプレート検索 → フィードバック → BGM選択 → 撮影開始

#### Session永続化
各ProjectごとにLanguageModelSessionを保持し、アプリ再起動後も会話履歴を維持

### Tools定義（Foundation Models Tool Protocol）

#### 1. TemplateSearchTool（最優先）
ユーザーの希望に合うVlogテンプレートを検索。MockTemplateRepositoryから取得し、クエリとカテゴリでフィルタリング。

**パラメータ**: query（String）、category（String?）

#### 2. VideoAnalysisTool
添付動画を解析し、セグメントに自動マッピング。MockGeminiRepository.analyzeVideo()を呼び出し（Gemini APIでしか実装できない）。

**パラメータ**: videoURL（String）

#### 3. BGMSelectionTool
テンプレートに合うBGMを提案。MockBGMRepositoryから取得し、テンプレート名とmoodでフィルタ、上位3件を推薦。

**パラメータ**: templateId（String）、mood（String?）

### ハイブリッド実行戦略

- **オンデバイス**: 会話、テンプレート検索、BGM選択
- **Gemini API**: 動画分析（VideoAnalysisToolの実装内部で使用）
- **フォールバック**: LanguageModelError.notAvailable検知時、会話全体をGeminiRepositoryで代替

---

## Agentic機能の詳細

### マルチステップ推論

AIの思考プロセスを段階的に表示。ThinkingStepType: reasoning（推論中）、analyzing（分析中）、planning（計画中）、concluding（結論中）。ThinkingProcessViewでタイムライン形式表示、紫背景で強調。

### プロアクティブな質問生成

システムプロンプトで指示し、AIが自律的に質問を生成。会話フェーズ（初期→詳細化→提案→確認→BGM選択）に応じて適切な質問をする。

### 記憶と文脈理解

LanguageModelSessionの永続化により会話履歴を維持。Foundation Modelsが内部的に履歴管理、SwiftDataのChatMessageは表示・記録用。SyncChatHistoryUseCaseで同期。

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

## データフロー

User Input → ChatViewModel.sendMessage() → SendMessageWithAIUseCase → FoundationModelRepository → LanguageModelSession → AsyncThrowingStream（.text / .toolCall / .thinkingStep / .complete） → ViewModel更新 → SwiftUI描画 → SwiftData保存

Tool実行: LanguageModelSessionがツール呼び出し判断 → Tool実行（TemplateSearch / VideoAnalysis / BGMSelection） → 結果をSessionにフィードバック → AIが結果を踏まえて応答生成

---

## エラーハンドリング

**ChatError**: sessionNotInitialized、foundationModelsUnavailable、toolExecutionFailed、streamingInterrupted、invalidToolParameters、networkUnavailable

**主要ケース**:
- LanguageModelError.notAvailable: GeminiRepositoryへ自動フォールバック、エラーメッセージ表示
- ネットワーク不可: NWPathMonitorで監視、オンデバイスのみ動作（動画分析は不可）
- ツール実行失敗: エラーメッセージ表示、会話継続

---

## 技術制約と要件

- **iOS 26 / A17 Pro以降のiPhone必須**
- **地域制限あり**（Foundation Modelsのロールアウト状況による）
- **モデルサイズ**: ~3Bパラメータ（複雑な推論には限界あり）
- **コンテキストウィンドウ**: 長い会話は要約が必要な場合あり
