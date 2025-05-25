# ADR-014: Kamalデプロイメント設定

## ステータス

採用

## 決定日

2025-05-25

## コンテキスト

Rails アプリケーション spotlight-rails の本番環境デプロイメントシステムとして Kamal を導入する必要がある。

### 要件
- ホスト: www-takeyuweb-co-jp
- ドメイン: takeyuweb.co.jp
- SSL証明書の自動取得・更新
- SQLite データベースの永続化
- ゼロダウンタイムデプロイメント

## 決定

Kamal を使用したコンテナベースのデプロイメントシステムを採用する。

### 主要な設定内容

#### 1. サービス設定
- サービス名: spotlight-rails
- イメージ名: spotlight-rails
- レジストリ: takeyuwebinc-spotlight-rails.sakuracr.jp (Sakura Cloud Registry)

#### 2. インフラ設定
- デプロイ先サーバー: www-takeyuweb-co-jp
- プロキシ: kamal-proxy with SSL termination
- ドメイン: takeyuweb.co.jp
- SSL証明書: Let's Encrypt による自動取得・更新

#### 3. データ永続化
- SQLite データベースファイルの永続化
- ボリュームマウント: `/var/lib/spotlight-rails/storage:/rails/storage`

#### 4. 環境変数
- RAILS_MASTER_KEY: Rails アプリケーションの暗号化キー
- レジストリ認証情報: KAMAL_REGISTRY_USERNAME, KAMAL_REGISTRY_PASSWORD

#### 5. ヘルスチェック
- エンドポイント: `/up`
- ポート: 80
- 最大試行回数: 7回
- 間隔: 20秒

## 理由

### Kamal 採用の理由
1. **Rails 標準**: Rails 8 で標準的に含まれるデプロイメントツール
2. **シンプルな設定**: 複雑なオーケストレーションツールと比較して設定が簡潔
3. **ゼロダウンタイム**: ローリングデプロイメントによる無停止更新
4. **SSL自動化**: Let's Encrypt による証明書の自動取得・更新

### アーキテクチャの利点
1. **コンテナ化**: Docker による環境の一貫性
2. **プロキシ統合**: kamal-proxy による HTTP/HTTPS トラフィック管理
3. **データ永続化**: SQLite ファイルの適切な永続化
4. **セキュリティ**: 環境変数による機密情報の管理

## 影響

### ポジティブな影響
- 本番環境への安全で確実なデプロイメント
- SSL証明書の自動管理
- ゼロダウンタイムでの更新
- 設定の標準化とバージョン管理

### 考慮事項
- サーバーへのSSHアクセスが必要
- Docker レジストリの認証情報管理
- SQLite の制限（単一サーバー環境）

## 実装詳細

### 作成されたファイル
1. `config/deploy.yml` - Kamal メイン設定
2. `.kamal/secrets` - 環境変数テンプレート
3. `.gitignore` 更新 - secrets ファイルの除外
4. `config/environments/production.rb` 更新 - ドメイン設定

### デプロイメントコマンド
```bash
# 初回デプロイ
kamal setup

# 通常のデプロイ
kamal deploy

# ログ確認
kamal app logs

# アプリケーション再起動
kamal app restart
```

## 関連資料

- [Kamal 公式ドキュメント](https://kamal-deploy.org/)
- [Rails Deployment Guide](https://guides.rubyonrails.org/deployment.html)
