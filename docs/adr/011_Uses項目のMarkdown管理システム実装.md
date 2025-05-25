# ADR-011: Uses項目のMarkdown管理システム実装

## ステータス

承認済み

## コンテキスト

`/uses` ページは現在、静的なHTMLテンプレートでハードコーディングされており、コンテンツの更新にはコードの変更が必要でした。ツールやガジェットの情報を効率的に管理し、個別のアイテムを構造化して表示するシステムが必要でした。

## 決定

個別のアイテム（ツールやガジェット）をMarkdownファイルで管理し、データベースに保存して動的に表示するシステムを実装しました。

### 主要な設計決定

1. **UsesItemモデルの導入**
   - 個別アイテムを構造化データとして管理
   - カテゴリ別の分類とソート機能

2. **個別ファイル管理方式の採用**
   - カテゴリディレクトリ内に個別のMarkdownファイル
   - 将来的なArticleとの連携を考慮した拡張性

3. **既存パターンとの一貫性**
   - ArticleやProjectと同様のYAMLフロントマター
   - MetadataParserサービスの拡張
   - 統一されたインポートワークフロー

## 実装詳細

### データモデル
```ruby
class UsesItem < ApplicationRecord
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :category, presence: true
  validates :description, presence: true
  
  scope :published, -> { where(published: true) }
  scope :ordered, -> { order(:position, :created_at) }
end
```

### ディレクトリ構造
```
docs/published/uses/
├── workstation/
├── development/
├── design/
├── productivity/
└── everyday-carry/
```

### YAMLフロントマター
```yaml
category: uses_item
name: "アイテム名"
slug: "url-slug"
item_category: "カテゴリ名"
url: "商品URL（オプション）"
position: 表示順序
published: true/false
```

### インポート機能
- `bin/rails db:import` でMarkdownファイルを一括インポート
- MetadataParserに "uses_item" カテゴリサポートを追加
- 既存データの更新に対応

## 代替案

### 1. ページ全体のMarkdown管理
- **却下理由**: 個別アイテムの管理が困難、将来的な拡張性に欠ける

### 2. ファイルベースの直接読み込み
- **却下理由**: 既存パターンとの不整合、キャッシュ管理の複雑さ

### 3. カテゴリ別ファイル管理
- **却下理由**: 個別アイテムの細かい管理ができない

## 結果

### 利点
- **コンテンツ管理の効率化**: Markdownファイルでの直感的な編集
- **構造化データ**: カテゴリ別の分類と柔軟な表示制御
- **一貫性**: 既存のArticle/Projectパターンとの統一
- **拡張性**: 将来的な機能追加に対応可能
- **バージョン管理**: Gitでのコンテンツ履歴管理

### 実装された機能
- 個別アイテムのMarkdown管理
- カテゴリ別の自動分類表示
- URLリンク機能
- 表示順序制御
- 公開/非公開制御

### 運用改善
- コンテンツ更新にコード変更が不要
- `bin/rails db:import` での簡単なデプロイ
- Markdownエディタでの快適な編集体験

## 将来的な拡張計画

- 個別アイテムページ (`/uses/:slug`)
- カテゴリページ (`/uses/categories/:category`)
- 検索・フィルタ機能
- 価格・評価情報の追加
- Articleとの連携（レビュー記事へのリンク）

## 関連ファイル

- `app/models/uses_item.rb`
- `db/migrate/20250525073625_create_uses_items.rb`
- `app/services/metadata_parser.rb`
- `app/controllers/uses_controller.rb`
- `app/views/uses/index.html.erb`
- `lib/tasks/import.rake`
- `docs/spec/uses_items_feature.md`
