# Uses Items Feature Specification

## 概要

`/uses` ページをMarkdown原稿で管理できるシステムを実装。個別のアイテム（ツールやガジェット）を構造化して管理し、カテゴリ別に表示する。

## 機能要件

### 1. データモデル

#### UsesItemモデル
- `name` (string, required) - アイテム名
- `slug` (string, required, unique) - URL用スラッグ
- `category` (string, required) - カテゴリ名
- `description` (text, required) - 説明文（HTML）
- `url` (string, optional) - 商品・サービスURL
- `position` (integer, default: 999) - カテゴリ内での表示順序
- `published` (boolean, default: true) - 公開フラグ

### 2. Markdownファイル管理

#### ディレクトリ構造
```
docs/published/uses/
├── workstation/
│   ├── macbook-pro-m2-2023.md
│   ├── dell-u2720q-monitor.md
│   └── ...
├── development/
│   ├── visual-studio-code.md
│   └── ...
├── design/
│   ├── figma.md
│   └── ...
├── productivity/
│   ├── notion.md
│   └── ...
└── everyday-carry/
    ├── iphone-15-pro.md
    └── ...
```

#### YAMLフロントマター仕様
```yaml
---
category: uses_item
name: "MacBook Pro M2 Pro, 32GB RAM (2023)"
slug: "macbook-pro-m2-2023"
item_category: "workstation"
url: "https://www.apple.com/macbook-pro/"
position: 1
published: true
---

アイテムの説明文をMarkdownで記述。
```

### 3. インポート機能

#### Rakeタスク
```bash
bin/rails db:import
```

- `docs/published/uses/` ディレクトリを再帰的に検索
- YAMLフロントマターを解析
- Markdownコンテンツを HTML に変換
- データベースに保存

#### MetadataParser拡張
- "uses_item" カテゴリのサポート追加
- 必須フィールド: `name`, `slug`, `item_category`
- デフォルト値設定: `position`, `published`

### 4. 表示機能

#### UsesController#index
```ruby
def index
  @items_by_category = UsesItem.published
                               .ordered
                               .group_by(&:category)
end
```

#### ビューテンプレート
- カテゴリごとにセクション分け
- アイテム名にURL リンク（URLが設定されている場合）
- 説明文をHTMLとして表示
- 既存のデザインを維持

## 技術仕様

### 1. データベース設計

```sql
CREATE TABLE uses_items (
  id BIGINT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(255) NOT NULL UNIQUE,
  category VARCHAR(255) NOT NULL,
  description TEXT NOT NULL,
  url VARCHAR(255),
  position INTEGER DEFAULT 999,
  published BOOLEAN DEFAULT true,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX index_uses_items_on_slug ON uses_items (slug);
CREATE INDEX index_uses_items_on_category ON uses_items (category);
CREATE INDEX index_uses_items_on_category_and_position ON uses_items (category, position);
```

### 2. バリデーション

```ruby
validates :name, presence: true
validates :slug, presence: true, uniqueness: true
validates :category, presence: true
validates :description, presence: true
```

### 3. スコープ

```ruby
scope :by_category, ->(category) { where(category: category) }
scope :published, -> { where(published: true) }
scope :ordered, -> { order(:position, :created_at) }
```

## 運用方法

### 1. 新しいアイテムの追加

1. 適切なカテゴリディレクトリに Markdown ファイルを作成
2. YAMLフロントマターを設定
3. アイテムの説明をMarkdownで記述
4. `bin/rails db:import` でインポート

### 2. 既存アイテムの更新

1. Markdownファイルを編集
2. `bin/rails db:import` で再インポート（既存データを更新）

### 3. カテゴリの管理

- カテゴリ名は `item_category` フィールドで指定
- ディレクトリ名とカテゴリ名は一致させることを推奨
- 表示時は `category.humanize` で自動的に整形

## 将来的な拡張

- 個別アイテムページ (`/uses/:slug`)
- カテゴリページ (`/uses/categories/:category`)
- 検索・フィルタ機能
- 価格・評価情報の追加
- Article との連携（レビュー記事へのリンク）

## 実装ファイル

- `app/models/uses_item.rb` - モデル定義
- `db/migrate/20250525073625_create_uses_items.rb` - マイグレーション
- `app/services/metadata_parser.rb` - YAMLパーサー拡張
- `app/controllers/uses_controller.rb` - コントローラー
- `app/views/uses/index.html.erb` - ビューテンプレート
- `lib/tasks/import.rake` - インポートタスク
