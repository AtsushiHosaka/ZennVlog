# Home Feature

## 概要
アプリのメイン画面（ダッシュボード）。進行中のプロジェクトや次に撮るべき素材を強調表示する。

## 状態（ViewModel）

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| inProgressProjects | [Project] | 進行中のプロジェクト一覧 |
| recentProjects | [Project] | 最近更新したプロジェクト一覧 |
| completedProjects | [Project] | 完成したVlog一覧 |
| isLoading | Bool | ローディング状態 |
| errorMessage | String? | エラーメッセージ |
| showChat | Bool | チャット画面表示フラグ |
| newProjectInput | String | 「つくりたいもの」の入力テキスト |

## ユーザーアクション

1. **「つくりたいもの」カードをタップ** → チャット画面（フルスクリーンモーダル）を表示
2. **進行中プロジェクトをタップ** → 撮影画面へ遷移
3. **最近のプロジェクトをタップ** → そのプロジェクトの状態に応じた画面へ遷移
4. **完成したVlogをタップ** → プレビュー画面へ遷移

## 遷移先

- ChatView（フルスクリーンモーダル）
- RecordingView（NavigationLink）
- PreviewView（NavigationLink）

## UseCase

- `FetchDashboardUseCase` - プロジェクト一覧を取得し、状態別に分類

## コンポーネント設計

### 設計方針
ダッシュボードは表示内容が変わりやすいため、コンポーネントを以下の原則で設計：
- **セクションの独立性**: 追加・削除・並び替えが容易
- **カードの汎用性**: データ駆動で表示内容を制御
- **レイアウトの柔軟性**: セクションの表示/非表示、順序変更が簡単
- **データの分離**: 各セクションに必要最小限のデータのみ渡す

### コンポーネント階層
- `HomeView` - メインビュー
  - `CreateNewCard` - つくりたいものカード（独立）
  - `DashboardSection<T>` - 汎用セクションコンポーネント（ジェネリック）
    - `InProgressProjectCard` - 進行中プロジェクトカード
    - `RecentProjectCard` - 最近のプロジェクトカード
    - `CompletedVlogCard` - 完成したVlogカード

### DashboardSection（汎用）
**プロパティ**: title, items: [T], emptyMessage, showAll, content: (T) -> Content

**利点**: 新しいセクション追加時に再利用可能、レイアウトを統一的に管理

### 各カードの詳細

#### CreateNewCard
- チャット風TextField（iMessageライク）、プレースホルダー「何を作りたい？」
- 入力後Enterでチャット画面へ遷移

#### InProgressProjectCard
- **表示**: プロジェクト名、進捗状況（3/5）、次に撮る素材（強調）
- **レイアウト**: 次に撮る素材を大きく目立たせる
- **タップ**: 撮影画面へ遷移

#### RecentProjectCard
- **表示**: サムネイル、プロジェクト名、更新日時
- **レイアウト**: 横並び（サムネイル左、情報右）
- **タップ**: プロジェクト状態に応じた画面へ（撮影中→Recording、完成→Preview）

#### CompletedVlogCard
- **表示**: サムネイル、プロジェクト名、再生時間、完成日
- **レイアウト**: グリッド型またはリスト型
- **タップ**: プレビュー画面へ遷移

## データフロー

アプリ起動 → HomeViewModel.onAppear() → FetchDashboardUseCase → ProjectRepository.fetchAll() → プロジェクト一覧を状態別に分類（進行中/最近/完成） → @Published変数更新 → SwiftUI描画

## 状態管理とロジック

### プロジェクト分類
- **進行中**: `status == .recording && hasIncompleteSegments`
- **最近**: `updatedAt`でソート、上位5-10件
- **完成**: `status == .completed`

### 次に撮る素材の判定
未撮影セグメントの最初のもの: `segments.first(where: { $0.videoAsset == nil })`

### ViewModelのデータ分離
```swift
@Published var inProgressProjects: [InProgressProjectData]
@Published var recentProjects: [RecentProjectData]
@Published var completedVlogs: [CompletedVlogData]
```
各データ型は必要な情報のみを含む軽量な構造体。セクションごとに独立したデータ構造により、変更の影響範囲を限定。

## エラーハンドリング

- **取得失敗**: エラーメッセージ表示、リトライボタン
- **空状態**: 「プロジェクトがありません」表示、つくりたいものカードを強調

## 注意点

- 初回起動時（プロジェクト0件）は自動的にチャット画面へ遷移、新規プロジェクト自動作成
- 各セクションは独立コンポーネントとして実装、追加・削除・並び替えが容易
- 進行中プロジェクトでは「次に撮る素材」を強調表示
- 将来的な拡張: 設定ファイルでセクション順序や表示/非表示を制御可能
