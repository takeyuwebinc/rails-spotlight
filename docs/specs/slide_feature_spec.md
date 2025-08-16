# Markdownスライド機能 機能設計書

## 1. URLマップ

### 1.1 公開URL
| URL | 説明 | 表示内容 |
|-----|------|----------|
| `/slides/:slug` | スライド表示画面 | 指定されたスライドをHTMLで表示 |
| `/tags/:tag_slug` | タグ別一覧 | 記事とスライドを統合表示 |
| `/` | トップページ | 最新の記事とスライドを表示 |

### 1.2 管理URL（開発環境のみ）
| URL | 説明 | 表示内容 |
|-----|------|----------|
| `/slides/:slug?draft=true` | 下書きプレビュー | 未公開スライドの確認 |

## 2. データモデル設計

### 2.1 Slideモデル

```ruby
# app/models/slide.rb
class Slide < ApplicationRecord
  has_many :slide_pages, -> { order(:position) }, dependent: :destroy
  has_many :slide_tags, dependent: :destroy
  has_many :tags, through: :slide_tags
  
  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :description, presence: true
  validates :published_at, presence: true
  
  scope :published, -> { where("published_at <= ?", Time.current).order(published_at: :desc) }
  scope :draft, -> { where("published_at > ?", Time.current) }
  scope :tagged_with, ->(tag_slug) { joins(:tags).where(tags: { slug: tag_slug }) }
  
  def to_param
    slug
  end
  
  def published?
    published_at <= Time.current
  end
  
  def draft?
    !published?
  end
  
  def page_count
    slide_pages.count
  end
  
  def page_at(position)
    slide_pages.find_by(position: position)
  end
end
```

### 2.2 SlidePageモデル

```ruby
# app/models/slide_page.rb
class SlidePage < ApplicationRecord
  belongs_to :slide
  
  validates :content, presence: true
  validates :position, presence: true, uniqueness: { scope: :slide_id }
  
  scope :ordered, -> { order(:position) }
  
  def next_page
    slide.slide_pages.find_by(position: position + 1)
  end
  
  def previous_page
    slide.slide_pages.find_by(position: position - 1)
  end
  
  def first?
    position == 1
  end
  
  def last?
    position == slide.page_count
  end
end
```

### 2.3 マイグレーション

```ruby
# db/migrate/xxx_create_slides.rb
class CreateSlides < ActiveRecord::Migration[7.1]
  def change
    create_table :slides do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :description, null: false
      t.datetime :published_at, null: false
      
      t.timestamps
    end
    
    add_index :slides, :slug, unique: true
    add_index :slides, :published_at
  end
end

# db/migrate/xxx_create_slide_pages.rb
class CreateSlidePages < ActiveRecord::Migration[7.1]
  def change
    create_table :slide_pages do |t|
      t.references :slide, null: false, foreign_key: true
      t.text :content, null: false
      t.integer :position, null: false
      
      t.timestamps
    end
    
    add_index :slide_pages, [:slide_id, :position], unique: true
  end
end

# db/migrate/xxx_create_slide_tags.rb
class CreateSlideTags < ActiveRecord::Migration[7.1]
  def change
    create_table :slide_tags do |t|
      t.references :slide, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true
      
      t.timestamps
    end
    
    add_index :slide_tags, [:slide_id, :tag_id], unique: true
  end
end
```

## 3. コントローラー設計

### 3.1 SlidesController

```ruby
# app/controllers/slides_controller.rb
class SlidesController < ApplicationController
  before_action :set_slide
  before_action :check_draft_access
  
  def show
    @current_page = params[:page]&.to_i || 1
    @slide_page = @slide.page_at(@current_page)
    
    if @slide_page.nil?
      redirect_to slide_path(@slide, page: 1)
      return
    end
    
    render layout: "slide"
  end
  
  private
  
  def set_slide
    @slide = Slide.find_by!(slug: params[:id])
  end
  
  def check_draft_access
    if @slide.draft? && !Rails.env.local?
      raise ActiveRecord::RecordNotFound
    end
  end
end
```

## 4. インポート機能

### 4.1 Slide.import_from_markdown

```ruby
# app/models/slide.rb
class Slide < ApplicationRecord
  def self.import_from_markdown(markdown_content)
    # MetadataParserを使用してメタデータ解析
    parsed_data = MetadataParser.parse(markdown_content)
    metadata = parsed_data[:metadata]
    content = parsed_data[:content]
    
    # カテゴリがslideの場合のみ処理
    return nil unless metadata[:category] == "slide"
    
    # スライドの検索または初期化
    slide = find_or_initialize_by(slug: metadata[:slug])
    
    # 属性の更新
    slide.assign_attributes(
      title: metadata[:title],
      description: metadata[:description],
      published_at: metadata[:published_date]
    )
    
    # トランザクション内で保存
    ActiveRecord::Base.transaction do
      if slide.save
        # 既存のページを削除
        slide.slide_pages.destroy_all
        
        # 新しいページを作成
        create_slide_pages(slide, content)
        
        # タグの処理
        process_tags(slide, metadata[:tags])
        
        slide
      else
        Rails.logger.error "Error saving slide: #{slide.errors.full_messages.join(', ')}"
        nil
      end
    end
  rescue => e
    Rails.logger.error "Error processing slide: #{e.message}"
    nil
  end
  
  private
  
  def self.create_slide_pages(slide, markdown_content)
    # スライドを---で分割
    pages = markdown_content.split(/^---$/m).map(&:strip).reject(&:empty?)
    
    # 各ページをHTMLにレンダリングして保存
    renderer = CustomHtmlRenderer.new(hard_wrap: true)
    markdown = Redcarpet::Markdown.new(renderer, {
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      highlight: true
    })
    
    pages.each_with_index do |page_content, index|
      # Marpディレクティブの処理
      processed_content = process_marp_directives(page_content)
      html_content = markdown.render(processed_content)
      
      slide.slide_pages.create!(
        content: html_content,
        position: index + 1
      )
    end
  end
  
  def self.process_marp_directives(content)
    # Marpディレクティブを削除（HTMLコメントとして残っているもの）
    content.gsub(/<!--\s*\w+:\s*\w+\s*-->/, '')
  end
  
  def self.process_tags(slide, tag_names)
    return unless tag_names
    
    slide.tags.clear
    tag_names.each do |tag_name|
      next if tag_name.blank?
      
      tag = Tag.find_or_create_by(name: tag_name)
      slide.tags << tag unless slide.tags.include?(tag)
    end
  end
end
```

### 4.2 インポートタスクの拡張

```ruby
# lib/tasks/import.rake
namespace :db do
  desc "Import content from docs directory"
  task import: :environment do
    # 既存の記事インポート
    article_count = Article.import_from_docs("docs/published/articles")
    puts "Imported #{article_count} articles"
    
    # スライドインポート
    slide_count = Slide.import_from_docs("docs/published/slides")
    puts "Imported #{slide_count} slides"
  end
end
```

## 5. ビュー設計

### 5.1 スライド表示レイアウト

```erb
<!-- app/views/layouts/slide.html.erb -->
<!DOCTYPE html>
<html>
  <head>
    <title><%= @slide.title %> - Slides</title>
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_include_tag "application", "data-turbo-track": "reload", defer: true %>
  </head>
  <body class="slide-view">
    <div data-controller="slide-viewer" 
         data-slide-viewer-total-value="<%= @slide.page_count %>"
         data-slide-viewer-current-value="<%= @slide_page.position %>">
      <%= yield %>
    </div>
  </body>
</html>
```

### 5.2 スライド表示ビュー

```erb
<!-- app/views/slides/show.html.erb -->
<div class="slide-container">
  <header class="slide-header">
    <h1><%= @slide.title %></h1>
    <div class="slide-meta">
      <span class="slide-date"><%= @slide.published_at.strftime("%Y年%m月%d日") %></span>
      <span class="slide-pages"><%= @slide_page.position %> / <%= @slide.page_count %></span>
    </div>
  </header>
  
  <main class="slide-content" data-slide-viewer-target="content">
    <%= @slide_page.content.html_safe %>
  </main>
  
  <nav class="slide-navigation">
    <% unless @slide_page.first? %>
      <%= link_to "前へ", slide_path(@slide, page: @slide_page.position - 1), 
          class: "slide-nav-prev", 
          data: { turbo_frame: "slide-frame" } %>
    <% end %>
    
    <% unless @slide_page.last? %>
      <%= link_to "次へ", slide_path(@slide, page: @slide_page.position + 1), 
          class: "slide-nav-next", 
          data: { turbo_frame: "slide-frame" } %>
    <% end %>
  </nav>
  
  <footer class="slide-footer">
    <div class="slide-tags">
      <% @slide.tags.each do |tag| %>
        <%= link_to tag.name, tag_path(tag), class: "tag-badge" %>
      <% end %>
    </div>
  </footer>
</div>
```

## 6. Stimulusコントローラー

```javascript
// app/javascript/controllers/slide_viewer_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]
  static values = { current: Number, total: Number }
  
  connect() {
    // キーボードイベントのリスナー追加
    document.addEventListener("keydown", this.handleKeydown.bind(this))
  }
  
  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown.bind(this))
  }
  
  handleKeydown(event) {
    switch(event.key) {
      case "ArrowLeft":
        this.previousSlide()
        break
      case "ArrowRight":
        this.nextSlide()
        break
    }
  }
  
  previousSlide() {
    if (this.currentValue > 1) {
      window.location.href = `/slides/${this.slideSlug}?page=${this.currentValue - 1}`
    }
  }
  
  nextSlide() {
    if (this.currentValue < this.totalValue) {
      window.location.href = `/slides/${this.slideSlug}?page=${this.currentValue + 1}`
    }
  }
  
  get slideSlug() {
    return window.location.pathname.split("/")[2]
  }
}
```

## 7. ヘルパーメソッド

```ruby
# app/helpers/slides_helper.rb
module SlidesHelper
  # スライドのページ番号付きリンクを生成
  def slide_page_path(slide, page)
    slide_path(slide, page: page)
  end
  
  # タグバッジの表示
  def slide_tag_badge(tag)
    link_to tag.name, tag_path(tag), 
      class: "inline-block px-3 py-1 text-sm font-medium rounded-full #{tag.badge_colors[:bg_color]} #{tag.badge_colors[:text_color]}"
  end
end
```

## 8. スラッシュコマンド設計

### 8.1 /project:slide-create

```markdown
# .claude/commands/slide-create.md
---
description: 新規スライドの作成支援
usage: /project:slide-create <topic>
---

スライド作成の支援を開始します。

1. トピックについてヒアリング
2. 対象聴衆の確認
3. 発表時間の確認
4. 構成の提案
5. スライドテンプレートの生成
```

### 8.2 /project:slide-review

```markdown
# .claude/commands/slide-review.md
---
description: スライドの推敲・改善
usage: /project:slide-review <slide_path>
---

既存スライドのレビューと改善提案を行います。

1. 構成の評価
2. 内容の明確性チェック
3. ビジュアル要素の提案
4. 改善案の提示
```

## 9. テンプレート

```markdown
# docs/templates/slide.md
---
title: スライドタイトル
slug: slide-slug
category: slide
published_date: 2025-08-16
description: スライドの説明文
tags:
  - Technology
  - Presentation
---

<!-- theme: default -->
<!-- paginate: true -->

# スライドタイトル

発表者名
日付

---

# アジェンダ

1. はじめに
2. 本題
3. まとめ

---

# はじめに

内容

---

# 本題

詳細内容

---

# まとめ

- ポイント1
- ポイント2
- ポイント3

---

# ご清聴ありがとうございました

質問はありますか？
```

## 10. セキュリティ考慮事項

1. **下書きアクセス制御**
   - `Rails.env.local?`でのみアクセス可能
   - 本番環境では404エラー

2. **XSS対策**
   - Markdownレンダリング時のサニタイズ
   - CustomHtmlRendererでの適切なエスケープ

3. **CSRF対策**
   - 標準のRails CSRF保護を使用