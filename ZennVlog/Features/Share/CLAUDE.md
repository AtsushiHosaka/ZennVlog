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

## 注意点

- UIActivityViewControllerを使用してシステムの共有シートを表示
- 端末保存はPHPhotoLibraryを使用
- 写真ライブラリへの書き込み権限が必要
