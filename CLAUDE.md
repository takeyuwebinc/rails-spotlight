# Claude Code ルール設定

## プロファイル機能

コンテキストに応じた専用の作業モードを提供します。

### 利用可能なプロファイル

- `development` - 開発モード（Rails開発専用）
- `review` - レビューモード（コードレビュー専用）
- `writing` - 記事執筆モード（記事作成・編集専用）

### 使用方法

```
/project:profile development
/project:profile review
/project:profile writing
```

スラッシュコマンドを実行すると、該当プロファイルのコンテキストが適用され、作業に最適化された環境で作業できます。

詳細なルールや設定については、各プロファイルの `.claude/profiles/` ディレクトリ内の設定ファイルを参照してください。
