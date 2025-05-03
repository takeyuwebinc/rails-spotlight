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
