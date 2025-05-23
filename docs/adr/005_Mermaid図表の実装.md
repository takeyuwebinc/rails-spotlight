# 4. Mermaid図表の実装

## ステータス

採用

## 日付

2025-05-18

## 背景

Markdownで記述された記事内に図表を埋め込む機能が必要となった。特に、フローチャート、シーケンス図、クラス図などを簡単に記述し、ブラウザ上で動的に描画できる機能が求められている。

## 決定

Mermaid.jsを使用して、Markdown内に記述されたmermaid構文のコードブロックを動的に図表として描画する機能を実装する。

具体的には以下の実装を行う：

1. Redcarpetのカスタムレンダラーを拡張し、mermaidコードブロックを検出して特別なHTMLコンテナに変換する
2. フロントエンドでStimulus.jsコントローラーを使用して、mermaid.jsライブラリを用いて図表を動的に描画する
3. ダークモード対応のため、テーマ切り替え時に図表を再描画する機能を実装する

## 実装詳細

### バックエンド（Markdownパーサー拡張）

`CustomHtmlRenderer`クラスに拡張モジュールが処理をフックできる仕組みを追加し、`MermaidExtension`モジュールでMermaidコードブロックを処理する。主な実装ポイントは以下の通り：

1. カスタムレンダラーに拡張機能を登録する仕組みを実装
2. Mermaidコードブロックを検出するハンドラーを登録
3. 検出したMermaidコードを特別なHTMLコンテナに変換

### フロントエンド実装

1. importmapにmermaid.jsライブラリを追加
2. Stimulusコントローラーを作成し、以下の機能を実装：
   - Mermaidライブラリの初期化と設定
   - コードブロックからの図表レンダリング
   - ダークモード切り替え時の再レンダリング
   - エラーハンドリングとユーザーへのフィードバック表示

## 代替案

1. **サーバーサイドでの事前レンダリング**：
   - Puppeteerを使用してサーバーサイドでmermaid図表を事前にSVGに変換する
   - メリット：クライアントサイドの処理が不要、初期表示が速い
   - デメリット：サーバーリソースの消費、ダークモード対応が複雑

2. **静的画像の埋め込み**：
   - 図表を静的画像として作成し、Markdownに埋め込む
   - メリット：シンプルな実装、ブラウザ互換性が高い
   - デメリット：図表の更新が面倒、ダークモード対応が困難

## 結論

Mermaid.jsを使用したクライアントサイドでの動的レンダリングを採用する。この方法は以下の利点がある：

1. Markdownに直接mermaid構文を記述できるため、図表の作成・更新が容易
2. クライアントサイドで描画するため、サーバーリソースを消費しない
3. ダークモードに対応した図表の描画が可能
4. インタラクティブな図表機能を将来的に拡張できる可能性がある

## 影響

- 新しいJavaScriptライブラリ（mermaid.js）への依存が追加される
- クライアントサイドでの処理が増えるため、ブラウザの負荷が若干増加する可能性がある
- 記事作成者はmermaid構文を学ぶ必要がある

## 関連リンク

- [Mermaid.js公式ドキュメント](https://mermaid.js.org/)
- [Redcarpet GitHub](https://github.com/vmg/redcarpet)
- [Stimulus.js公式ドキュメント](https://stimulus.hotwired.dev/)
