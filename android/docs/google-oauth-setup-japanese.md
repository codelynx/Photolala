# Google OAuth 設定手順（日本語）

## エラー: "Access blocked: Photolala has not completed the Google verification process"

このエラーは、OAuthアプリがテストモードのため発生します。テストユーザーとして自分を追加する必要があります。

## 手順:

### 1. プロジェクトを選択
- Google Cloud Consoleの上部にあるプロジェクトセレクターをクリック
- "Photolala"プロジェクトを選択（なければ作成）

### 2. OAuth同意画面へ移動
- 左側メニューで「APIとサービス」をクリック
- 「OAuth同意画面」を選択

### 3. テストユーザーを追加
- 「テストユーザー」セクションまでスクロール
- 「+ ユーザーを追加」をクリック
- `kaz.yoshikawa@gmail.com` を入力
- 「保存」をクリック

### 4. Google Photos Library APIを有効化
- 左メニューで「ライブラリ」をクリック
- 「Photos Library API」を検索
- クリックして「有効にする」

### 5. 必要なスコープの確認
OAuth同意画面で以下のスコープが設定されているか確認:
- email
- profile
- openid
- https://www.googleapis.com/auth/photoslibrary.readonly

## トラブルシューティング

まだサインインできない場合:
1. 数分待つ（変更の反映に時間がかかる場合があります）
2. アプリのデータ/キャッシュをクリア
3. 正しいGoogleアカウントを使用しているか確認
4. プロジェクトIDが一致しているか確認

## 開発用の設定

現在のアプリステータス:
- **公開ステータス**: テスト中
- **ユーザータイプ**: 外部
- **テストユーザー数**: 制限あり（最大100人）

本番環境への移行時は、Googleの検証プロセスを完了する必要があります。