# Kamal デプロイメントガイド

## 概要

このガイドでは、spotlight-rails アプリケーションを Kamal を使用してデプロイする手順を説明します。

## 前提条件

### サーバー側の準備
1. **Docker のインストール**
   ```bash
   # Ubuntu/Debian の場合
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   sudo usermod -aG docker $USER
   ```

2. **SSH アクセスの設定**
   - 公開鍵認証が設定されていること
   - パスワードなしでログインできること

### ローカル環境の準備
1. **Kamal gem のインストール確認**
   ```bash
   bundle install
   ```

2. **Docker のインストール**
   - ローカルでイメージをビルドするために必要

## 初期設定

### 1. 環境変数の設定

`.kamal/secrets` ファイルを編集して、実際の値を設定します：

```bash
# Rails application secrets
RAILS_MASTER_KEY=your_actual_rails_master_key

# Registry credentials for Sakura Cloud Registry
KAMAL_REGISTRY_USERNAME=your_registry_username
KAMAL_REGISTRY_PASSWORD=your_registry_password
```

**RAILS_MASTER_KEY の取得方法:**
```bash
cat config/master.key
```

### 2. サーバーへの接続確認

```bash
# SSH 接続テスト
ssh root@www-takeyuweb-co-jp

# Docker 動作確認
ssh root@www-takeyuweb-co-jp 'docker --version'
```

### 3. レジストリへのログイン確認

```bash
# ローカルでレジストリにログイン
docker login takeyuwebinc-spotlight-rails.sakuracr.jp
```

## デプロイメント手順

### 初回デプロイ

```bash
# 1. 設定の検証
kamal config

# 2. サーバーの準備とアプリケーションのデプロイ
kamal setup
```

`kamal setup` は以下を実行します：
- サーバーに Docker をインストール（必要に応じて）
- kamal-proxy の起動
- アプリケーションイメージのビルドとプッシュ
- アプリケーションコンテナの起動
- SSL証明書の取得

### 通常のデプロイ

```bash
# アプリケーションの更新
kamal deploy
```

### デプロイ状況の確認

```bash
# アプリケーションの状態確認
kamal app details

# ログの確認
kamal app logs

# プロキシの状態確認
kamal proxy details
```

## トラブルシューティング

### よくある問題と解決方法

#### 1. SSH 接続エラー
```bash
# SSH エージェントの確認
ssh-add -l

# 秘密鍵の追加
ssh-add ~/.ssh/id_rsa
```

#### 2. Docker レジストリ認証エラー
```bash
# レジストリへの再ログイン
docker login takeyuwebinc-spotlight-rails.sakuracr.jp

# 認証情報の確認
cat ~/.docker/config.json
```

#### 3. SSL証明書の問題
```bash
# プロキシの再起動
kamal proxy restart

# 証明書の状態確認
kamal proxy logs
```

#### 4. アプリケーションが起動しない
```bash
# 詳細なログの確認
kamal app logs --lines 100

# コンテナの状態確認
kamal app details

# 手動でのコンテナ起動テスト
kamal app exec -i bin/rails console
```

### ログの確認方法

```bash
# アプリケーションログ
kamal app logs

# プロキシログ
kamal proxy logs

# 特定の行数のログ
kamal app logs --lines 50

# リアルタイムログ
kamal app logs --follow
```

## メンテナンス操作

### アプリケーションの再起動
```bash
kamal app restart
```

### データベースマイグレーション
```bash
# マイグレーションの実行
kamal app exec bin/rails db:migrate

# マイグレーション状態の確認
kamal app exec bin/rails db:migrate:status
```

### コンソールアクセス
```bash
# Rails コンソール（インタラクティブモード）
kamal app exec -i bin/rails console

# Bash シェル（インタラクティブモード）
kamal app exec -i bash
```

### バックアップ

SQLite データベースのバックアップ：
```bash
# サーバー上でのバックアップ
ssh root@www-takeyuweb-co-jp 'cp -r /var/lib/spotlight-rails/storage /backup/$(date +%Y%m%d_%H%M%S)_spotlight_storage'
```

## セキュリティ考慮事項

1. **環境変数の管理**
   - `.kamal/secrets` ファイルは絶対にコミットしない
   - 定期的にパスワードを変更する

2. **SSH キーの管理**
   - 強力な SSH キーを使用する
   - 定期的にキーをローテーションする

3. **SSL証明書**
   - Let's Encrypt による自動更新を確認する
   - 証明書の有効期限を監視する

## 監視とアラート

### ヘルスチェック
アプリケーションは `/up` エンドポイントでヘルスチェックを提供します。

### ログ監視
定期的にアプリケーションログを確認し、エラーがないかチェックしてください。

```bash
# エラーログの検索
kamal app logs | grep -i error

# 警告ログの検索
kamal app logs | grep -i warn
```

## 参考資料

- [Kamal 公式ドキュメント](https://kamal-deploy.org/)
- [Rails デプロイメントガイド](https://guides.rubyonrails.org/deployment.html)
- [Docker 公式ドキュメント](https://docs.docker.com/)
