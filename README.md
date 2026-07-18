# docs

## リポジトリの目的
https://takeyuweb.co.jp として公開するRailsアプリケーション

## コンテンツの管理

コンテンツ（プロジェクト・Uses・登壇実績・スライド）はデータベースで管理し、MCP サーバー経由で作成・更新する（[ADR 022](docs/adr/022_docsの開発文書専用化.md)）。
リポジトリでは原稿を管理しない。

外部ディレクトリの markdown 原稿を取り込む場合は `db:import` タスクに取り込み元を指定して実行する：

```bash
bundle exec rails "db:import[/path/to/projects,/path/to/uses,/path/to/speaking,/path/to/slides]"
```

- markdownから title, slug, published_date といったメタデータを取り出す。
- markdown本文をHTMLに変換する。
- 対応するActiveRecordモデルレコードを更新または追加する。

## Claude Code

```bash
$ claude
```

### ブラウザ自動化機能

CLINEのブラウザアクション機能を使用するには、Puppeteer/Chromiumの依存関係が必要です。
開発環境では以下のコマンドで必要な依存関係をインストールできます：

```bash
$ bin/install-puppeteer-deps.sh
```

新しい開発環境では、`bin/claude-setup.sh` の実行時に自動的にインストールされます。

## API仕様書

```
bundle exec rails rswag:specs:swaggerize
```

http://localhost:3000/api-docs/

## MCP サーバー
記事の更新のためのMCPサーバーを実装しています。

### Claude Code（静的トークン認証）

```json:.mcp.json
{
  "mcpServers": {
    "spotlight-rails": {
      "type": "http",
      "url": "https://takeyuweb.co.jp/api/mcp",
      "method": "POST",
      "headers": {
        "Authorization": "Bearer token"
      }
    }
  }
}
```

### Claude AIアプリ（OAuth認証）

Claude AIアプリのカスタムコネクタでMCPサーバーに接続できます。

#### 設定値

| 項目 | 値 |
|------|-----|
| リモートMCPサーバーURL | `https://takeyuweb.co.jp/api/mcp` |
| OAuth Client ID | Doorkeeperで発行したクライアントID |
| OAuth クライアントシークレット | Doorkeeperで発行したクライアントシークレット |

#### OAuthクライアントの作成

Railsコンソールでクライアントを作成:

```ruby
rails console

app = Doorkeeper::Application.new(
  name: "Claude AI",
  redirect_uri: "https://claude.ai/api/mcp/auth_callback",
  scopes: "mcp",
  confidential: true
)
app.valid? # シークレット生成をトリガー
plaintext_secret = app.plaintext_secret # ハッシュ化前に取得
app.save!

puts "Client ID: #{app.uid}"
puts "Client Secret: #{plaintext_secret}"
```

**注意**: `hash_application_secrets`が有効なため、シークレットは作成時のみ表示されます。必ず安全な場所に保存してください。

#### OAuth設定詳細

| 項目 | 値 |
|------|-----|
| Authorization URL | `https://takeyuweb.co.jp/oauth/authorize` |
| Token URL | `https://takeyuweb.co.jp/oauth/token` |
| Scope | `mcp` |
| PKCE | 必須（S256） |
| アクセストークン有効期限 | 1時間 |
| リフレッシュトークン | 有効 |

#### Discovery Endpoints

OAuth設定はDiscovery Endpointから取得可能:

```bash
# Protected Resource Metadata
curl https://takeyuweb.co.jp/.well-known/oauth-protected-resource

# Authorization Server Metadata
curl https://takeyuweb.co.jp/.well-known/oauth-authorization-server
```
