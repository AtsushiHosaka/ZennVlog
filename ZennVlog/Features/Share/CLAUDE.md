# Share Feature

## 概要
完成したVlogをSNSに共有する画面。

## 状態（ViewModel）

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| project | Project | 現在のプロジェクト |
| exportedVideoURL | URL | 書き出し済み動画のURL |
| thumbnailImage | UIImage? | 動画のサムネイル |
| isSaving | Bool | 保存中フラグ |
| saveSuccess | Bool | 保存成功フラグ |
| errorMessage | String? | エラーメッセージ |

## ユーザーアクション

1. **SNSアイコンをタップ** → 各SNSアプリへ共有（UIActivityViewController）
2. **端末に保存ボタン** → カメラロールに保存
3. **[<]ボタン** → プレビュー画面に戻る

## 遷移先

- PreviewView（戻る）
- 外部アプリ（TikTok, Instagram, X等）

## UseCase

なし（システム機能のみ使用）

## コンポーネント

- `SNSButton` - SNS共有ボタン（TikTok, Instagram, X, その他）
  - **スタイル**: 円形アイコンボタン（各SNSのブランドカラー）
  - **対応SNS**: TikTok, Instagram, X（旧Twitter）, その他（UIActivityViewController）
  - **タップ動作**: 各SNSアプリへ共有、アプリ未インストール時は案内表示

## UI/UX詳細

### レイアウト
- 動画サムネイル（上部、大きく表示）
- プロジェクト名・情報（サムネイル下）
- SNS共有ボタン群（グリッド配置）
- 端末に保存ボタン（下部、目立つボタン）

### 保存成功時
- チェックマークアニメーション表示
- 「カメラロールに保存しました」トースト表示

### 保存失敗時
- エラーメッセージ表示
- 権限がない場合は設定画面への誘導

## データフロー

### 共有フロー
ユーザーがSNSボタンタップ → ShareViewModel.shareToSNS(platform) → UIActivityViewController表示（exportedVideoURLを渡す） → ユーザーが共有先を選択 → システムが共有処理を実行

### 端末保存フロー
ユーザーが保存ボタンタップ → ShareViewModel.saveToPhotoLibrary() → 写真ライブラリ権限チェック → PHPhotoLibrary.shared().performChanges → 保存成功（saveSuccess = true、トースト表示） / 権限なし（権限リクエスト表示、設定画面へ誘導）

## 状態管理とロジック

### 権限管理
- **写真ライブラリ**: PHAuthorizationStatusをチェック
- 権限がない場合: リクエストダイアログ表示
- 拒否された場合: 設定画面への誘導メッセージ

### 共有処理
- UIActivityViewControllerで標準共有シートを表示
- 共有可能なアイテム: exportedVideoURL、thumbnailImage（オプション）
- 共有完了/キャンセルのハンドリング

### 保存処理
- PHAssetChangeRequestを使用して動画を保存
- 保存中: isSaving = true、ProgressView表示
- 保存成功: saveSuccess = true、アニメーション表示

## エラーハンドリング

- **保存失敗**: エラーメッセージ表示、リトライボタン
- **権限拒否**: 設定画面へ誘導するアラート表示
- **動画ファイルなし**: 「動画の書き出しが完了していません」メッセージ

## 注意点

- UIActivityViewControllerを使用してシステムの共有シートを表示
- 端末保存はPHPhotoLibraryを使用
- 写真ライブラリへの書き込み権限が必要（初回は権限リクエスト表示）
- 権限拒否時は設定画面への誘導が必要
