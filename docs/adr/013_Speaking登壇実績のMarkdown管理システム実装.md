# ADR 013: Speaking登壇実績のMarkdown管理システム実装

## ステータス

採用

## 日付

2025-05-25

## 背景

/speaking ページの掲載内容がハードコードされており、新しい登壇実績を追加する際にHTMLファイルを直接編集する必要があった。コンテンツ管理の効率化と保守性向上のため、既存のUsesシステムと同様にMarkdownファイルでの管理システムが必要となった。

## 決定

Speaking登壇実績をMarkdownファイルで管理するシステムを実装する。

### 主要コンポーネント

1. **SpeakingEngagementモデル**
   - 登壇実績の情報を格納
   - タイトル、イベント名、開催日、場所、説明、URL等を管理
   - タグ情報をJSON形式で保存

2. **SpeakingController**
   - 専用コントローラーで登壇実績一覧を表示
   - HomeControllerからの分離

3. **MetadataParserサービスの拡張**
   - `speaking_engagement`カテゴリのサポート追加
   - 必須フィールドのバリデーション

4. **Markdownファイル構造**
   ```
   docs/published/speaking/
   ├── kaigi-on-rails-2024.md
   ├── shinjuku-rb-95.md
   └── ...
   ```

5. **インポート機能**
   - `rails db:import`タスクでの一括インポート
   - 既存のUsesシステムと統一されたワークフロー

### データベース設計

```sql
CREATE TABLE speaking_engagements (
  id BIGINT PRIMARY KEY,
  title VARCHAR NOT NULL,
  slug VARCHAR NOT NULL UNIQUE,
  event_name VARCHAR NOT NULL,
  event_date DATE NOT NULL,
  location VARCHAR,
  description TEXT,
  event_url VARCHAR,
  slides_url VARCHAR,
  tags TEXT, -- JSON配列
  position INTEGER DEFAULT 999,
  published BOOLEAN DEFAULT true,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

### Markdownファイル形式

```yaml
---
category: speaking_engagement
title: "登壇タイトル"
slug: "unique-slug"
event_name: "イベント名"
event_date: "2024-10-24"
location: "開催場所"
event_url: "https://example.com"
slides_url: "https://slides.example.com"
tags: ["Rails", "技術", "カンファレンス"]
position: 1
published: true
---

登壇の説明文（Markdown形式）
```

## 理由

### 1. 既存システムとの一貫性
- UsesシステムやArticleシステムと同じパターンを採用
- 統一されたワークフローとアーキテクチャ

### 2. コンテンツ管理の効率化
- Markdownファイルでの直感的な編集
- バージョン管理システムでの変更履歴追跡
- 非エンジニアでも編集可能

### 3. 保守性の向上
- ハードコードされたHTMLからの脱却
- データベース駆動の動的コンテンツ生成
- 既存レイアウトの完全踏襲

### 4. 拡張性
- 新しい登壇実績の簡単な追加
- タグシステムによる分類・検索機能の基盤
- 将来的な機能拡張への対応

## 影響

### 正の影響
- コンテンツ更新作業の大幅な効率化
- 登壇実績データの構造化と再利用性向上
- 既存システムとの統一性確保

### 考慮事項
- 新しいデータベーステーブルの追加
- インポート処理の実行が必要
- 既存のハードコードされたコンテンツからの移行

## 実装詳細

### 主要ファイル
- `app/models/speaking_engagement.rb`
- `app/controllers/speaking_controller.rb`
- `app/views/speaking/index.html.erb`
- `app/services/metadata_parser.rb`（拡張）
- `lib/tasks/import.rake`（拡張）

### マイグレーション
- `db/migrate/20250525083600_create_speaking_engagements.rb`

### ルーティング変更
```ruby
# 変更前
get "speaking" => "home#speaking"

# 変更後
get "speaking" => "speaking#index"
```

## 検証

実装後のテストにより以下を確認：
- /speaking ページの正常表示
- 2つの登壇実績の適切な表示
- タグシステムの動作
- イベントページ・発表資料へのリンク機能
- 既存レイアウトの完全踏襲

## 関連ADR

- ADR 011: Uses項目のMarkdown管理システム実装
- ADR 012: UsesControllerへのリファクタリング
