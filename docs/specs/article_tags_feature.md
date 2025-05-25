# 記事タグ機能仕様書

## 概要

記事にタグを付与し、タグによる記事の分類・検索機能を提供する。

## 機能要件

### 1. タグ管理機能

#### 1.1 タグモデル
- **フィールド**:
  - `name`: タグ名（必須、一意）
  - `slug`: URL用スラッグ（必須、一意、自動生成）
  - `color`: 表示色（デフォルト: 'gray'）
  - `created_at`, `updated_at`: タイムスタンプ

- **バリデーション**:
  - `name`: 存在必須、一意性
  - `slug`: 存在必須、一意性
  - `color`: 存在必須

- **関連**:
  - `has_many :article_tags`
  - `has_many :articles, through: :article_tags`

#### 1.2 記事タグ関連
- **中間テーブル**: `article_tags`
  - `article_id`: 記事ID（外部キー）
  - `tag_id`: タグID（外部キー）
  - 複合一意インデックス: `[article_id, tag_id]`

### 2. Markdownインポート機能

#### 2.1 frontmatterでのタグ指定
```
---
title: 記事タイトル
slug: article-slug
tags: Rails, JavaScript, DevOps
published_date: 2025-01-01
description: 記事の説明
---
```

#### 2.2 インポート処理
- frontmatterの `tags` フィールドを解析（カンマ区切り）
- 存在しないタグは自動作成
- 記事とタグの関連付けを実行
- タグのslugは `name.parameterize` で自動生成

### 3. 表示機能

#### 3.1 ホーム画面（home/index）
- 各記事にタグバッジを表示
- タグバッジはクリック可能
- クリック時はそのタグの記事一覧に遷移

#### 3.2 記事一覧画面（articles/index）
- タグによるフィルタリング機能
- URL: `/articles/tagged/:tag_slug`
- 選択中のタグを明示
- フィルタ解除機能

#### 3.3 タグバッジ表示
- 既存の `BadgeComponent` を活用
- タグごとに色分け可能
- ホバー効果でクリック可能であることを示す

### 4. ルーティング

```ruby
# 既存
get "articles" => "articles#index"

# 追加
get "articles/tagged/:tag" => "articles#index", as: :articles_by_tag
```

## 技術仕様

### 1. データベース設計

#### tagsテーブル
```sql
CREATE TABLE tags (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(255) NOT NULL,
  color VARCHAR(50) DEFAULT 'gray',
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  UNIQUE KEY index_tags_on_name (name),
  UNIQUE KEY index_tags_on_slug (slug)
);
```

#### article_tagsテーブル
```sql
CREATE TABLE article_tags (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  article_id BIGINT NOT NULL,
  tag_id BIGINT NOT NULL,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  UNIQUE KEY index_article_tags_on_article_id_and_tag_id (article_id, tag_id),
  FOREIGN KEY (article_id) REFERENCES articles(id),
  FOREIGN KEY (tag_id) REFERENCES tags(id)
);
```

### 2. モデル実装

#### Tagモデル
- `before_validation :generate_slug`
- `scope :ordered`
- `to_param` メソッドでslugを返却

#### Articleモデル拡張
- `scope :tagged_with`
- タグ関連のメソッド追加

### 3. コントローラー実装

#### ArticlesController
- `index` アクションでタグパラメータを処理
- タグフィルタリング時の記事取得

#### HomeController
- タグ情報を含む記事データの取得

## UI/UX仕様

### 1. タグバッジデザイン
- TailwindCSSを使用
- 既存のBadgeComponentを拡張
- ホバー時の視覚的フィードバック
- クリック可能であることを示すカーソル変更

### 2. レスポンシブ対応
- モバイル端末でのタグ表示最適化
- タグが多い場合の折り返し表示

### 3. アクセシビリティ
- タグリンクに適切なaria-label
- キーボードナビゲーション対応

## パフォーマンス考慮事項

### 1. データベースクエリ最適化
- N+1問題の回避（includes使用）
- 適切なインデックス設定

### 2. キャッシュ戦略
- タグ一覧のキャッシュ
- 記事とタグの関連データキャッシュ

## テスト要件

### 1. モデルテスト
- Tag, ArticleTagモデルのバリデーション
- 関連の動作確認
- スコープの動作確認

### 2. 統合テスト
- インポート機能のテスト
- タグフィルタリング機能のテスト

### 3. システムテスト
- タグバッジクリック動作
- 記事一覧フィルタリング動作

## 今後の拡張可能性

### 1. タグ管理画面
- 管理者向けタグCRUD機能
- タグの統合・分割機能

### 2. タグクラウド
- 人気タグの可視化
- タグ使用頻度の表示

### 3. タグ推奨機能
- 記事内容からのタグ自動推奨
- 関連タグの提案
