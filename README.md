# docs

## リポジトリの目的
https://takeyuweb.co.jp として公開するRailsアプリケーション

## コンテンツの管理
docs ディレクトリ

### コンテンツの反映

```ruby
bundle exec rails db:import
```

- docs/published 上のmarkdownファイルを探す。
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
