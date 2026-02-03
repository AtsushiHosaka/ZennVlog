# ProjectList Feature

## 概要
全プロジェクトのリスト表示画面。タブバーの2番目のタブ。

## 状態（ViewModel）

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| projects | [Project] | 全プロジェクト一覧 |
| isLoading | Bool | ローディング状態 |
| errorMessage | String? | エラーメッセージ |

## ユーザーアクション

1. **プロジェクトカードをタップ** → 撮影画面へ遷移

## 遷移先

- RecordingView（NavigationLink）

## UseCase

- `FetchProjectsUseCase` - 全プロジェクトを取得（更新日順ソート）

## コンポーネント

- `ProjectCard` - プロジェクトカード（サムネイル、名前、テーマ、ステータス、更新日）

## 注意点

- プロジェクト詳細画面は設けず、直接撮影画面に遷移
- リストは更新日順でソート
