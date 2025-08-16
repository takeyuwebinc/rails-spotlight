# Markdownスライド機能 要件定義書

## 1. 概要

takeyuweb.co.jpに、Markdownでスライドを作成・公開できる機能を追加する。技術者向けの発表資料を一元管理し、自己ブランディングの資産として活用することを目的とする。

## 2. 背景と目的

### 2.1 現状の課題
- 作成した発表資料が様々な外部サービスに分散している
- 自己ブランディングのための資産として十分に活用できていない

### 2.2 目的
- 技術者向けの発表資料を一元管理する
- 自己ブランディングの一環として活用する
- 見込み客の獲得につなげる
- AIの支援を受けながらスライドを作成し、そのまま公開できる環境を提供する

## 3. 機能要件

### 3.1 スライド管理機能

#### 3.1.1 基本仕様
- Markdown形式でスライドを作成・管理
- ファイルパス: `docs/published/slides/` に配置
- メタデータ管理: 記事と同様の形式（title, slug, published_date, tags等）
- カテゴリ: `slide` として管理

#### 3.1.2 Markdown記法
- Marp記法を踏襲
- `---` でスライドを区切る
- Marpのディレクティブ（theme、paginate等）をサポート

#### 3.1.3 テンプレート
- `docs/templates/slide.md` にスライドテンプレートを配置
- 新規作成時の雛形として利用

### 3.2 公開機能

#### 3.2.1 URL構成
- 公開URL: `/slides/{slug}`
- 一覧ページ: 記事一覧に統合して表示

#### 3.2.2 公開制御
- すべて公開（published_dateに基づく）
- 下書き状態: `Rails.env.local?` でのみURLを直接指定して表示可能
- 掲載開始日を指定可能（published_date）

### 3.3 表示機能

#### 3.3.1 スライドビューアー
- HTMLとTurboで実装
- スライドナビゲーション（前へ/次へ）
- スライド番号表示
- キーボード操作対応（矢印キー）

#### 3.3.2 レスポンシブ対応
- デスクトップ・タブレット・スマートフォンでの表示最適化

### 3.4 AI支援機能

#### 3.4.1 Claude Codeカスタムスラッシュコマンド
- コマンド名: `/project:slide-create` （新規作成）
- コマンド名: `/project:slide-review` （推敲・改善）

#### 3.4.2 支援内容
- 発表内容についてのヒアリング
- 効果的な構成の提案
- 作成した原稿の推敲
- スライドテンプレートの自動適用

### 3.5 データ統合

#### 3.5.1 タグ管理
- 記事と同じTagモデルを使用
- slide_tagsテーブルで関連付け

#### 3.5.2 一覧表示
- 記事一覧に統合表示
- カテゴリアイコンで記事とスライドを区別

## 4. 非機能要件

### 4.1 パフォーマンス
- 特別な要件なし（一般的なWebページと同等）

### 4.2 セキュリティ
- 下書き状態のスライドは開発環境でのみ表示

### 4.3 運用性
- `rails db:import` コマンドでスライドもインポート

### 4.4 拡張性
- 想定規模: 100スライド、1スライドあたり50ページ

### 4.5 互換性
- モダンブラウザのみ対応

## 5. データモデル設計

### 5.1 Slideモデル
```ruby
# app/models/slide.rb
class Slide < ApplicationRecord
  has_many :slide_tags, dependent: :destroy
  has_many :tags, through: :slide_tags
  
  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :description, presence: true
  validates :content, presence: true
  validates :published_at, presence: true
  
  scope :published, -> { where("published_at <= ?", Time.current).order(published_at: :desc) }
  scope :tagged_with, ->(tag_slug) { joins(:tags).where(tags: { slug: tag_slug }) }
end
```

### 5.2 テーブル定義
```sql
-- slides table
CREATE TABLE slides (
  id BIGSERIAL PRIMARY KEY,
  title VARCHAR NOT NULL,
  slug VARCHAR NOT NULL UNIQUE,
  description TEXT NOT NULL,
  content TEXT NOT NULL,
  published_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

-- slide_tags table
CREATE TABLE slide_tags (
  id BIGSERIAL PRIMARY KEY,
  slide_id BIGINT NOT NULL REFERENCES slides(id),
  tag_id BIGINT NOT NULL REFERENCES tags(id),
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  UNIQUE(slide_id, tag_id)
);
```

## 6. 画面設計

### 6.1 スライド表示画面（/slides/:slug）
- ヘッダー: タイトル、発表者情報、公開日
- メインエリア: スライド表示領域
- ナビゲーション: 前へ/次へボタン、スライド番号
- フッター: タグ、シェアボタン

### 6.2 一覧画面での表示
- 記事と同じカード形式
- カテゴリアイコンで「スライド」を明示
- タイトル、説明文、公開日、タグを表示

## 7. 実装方針

### 7.1 段階的実装
1. **Phase 1**: 基本機能の実装
   - Slideモデルとデータベース
   - Markdownパーサー（Marp記法対応）
   - 基本的な表示機能
   - インポート機能

2. **Phase 2**: UI/UX改善
   - スライドビューアーの実装
   - キーボード操作
   - レスポンシブ対応

3. **Phase 3**: AI支援機能
   - スラッシュコマンドの実装
   - テンプレート機能

### 7.2 技術スタック
- Backend: Ruby on Rails（既存）
- Frontend: Turbo、Stimulus（既存）
- Markdownパーサー: Redcarpet + Marp記法拡張
- スライド表示: HTML/CSS + Stimulus

## 8. 将来の拡張性

### 8.1 検討事項
- スピーカーノート機能
- プレゼンターモード
- PDFエクスポート
- アニメーション効果
- テーマカスタマイズ

### 8.2 設計上の配慮
- スライドビューアーをコンポーネント化
- プラグイン機構の検討
- API設計での拡張性確保

## 9. 制約事項

- スライド作成画面は提供しない（VSCode + コマンドラインでの執筆）
- 初期バージョンではMarp記法のみサポート
- リアルタイムプレビューは提供しない

## 10. 成功指標

- 発表資料の一元管理が実現できること
- スムーズなスライド表示が可能なこと
- AI支援により効率的にスライドが作成できること
- 既存の記事システムとシームレスに統合されること