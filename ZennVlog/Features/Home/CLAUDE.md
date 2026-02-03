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

## コンポーネント

- `CreateNewCard` - 「つくりたいもの」入力カード（チャット風TextField UI）
- `InProgressProjectSection` - 進行中プロジェクトセクション
- `RecentProjectsSection` - 最近のプロジェクトセクション
- `CompletedVlogsSection` - 完成したVlogセクション

## 注意点

- 初回起動時は自動的にチャット画面へ遷移（新規プロジェクト自動作成）
- 各セクションは独立コンポーネントとして実装し、追加・削除を容易にする
- 進行中プロジェクトでは「次に撮る素材」を強調表示する
