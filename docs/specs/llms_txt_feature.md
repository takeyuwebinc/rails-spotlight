# llms.txt提供機能 - 機能仕様書

## 1. 概要

### 1.1 目的
LLM（Large Language Model）がSpotlightサイトの内容を適切に理解し、利用できるようにするため、llms.txtファイルを動的に生成・提供する機能を実装する。

### 1.2 期待される効果
- タケユー・ウェブ株式会社の知名度向上
- LLMを通じた案件依頼への導線強化
- サイトコンテンツの機械可読性向上

### 1.3 仕様準拠
[llmstxt.org](https://llmstxt.org/)の仕様に準拠した形式で実装する。

## 2. 機能要件

### 2.1 エンドポイント
- **URL**: `/llms.txt`
- **メソッド**: GET
- **Content-Type**: `text/plain; charset=utf-8`

### 2.2 アクセス制御
- 認証不要（パブリックアクセス）
- レート制限なし
- robots.txtでクロール許可

### 2.3 生成方式
- 動的生成（Railsコントローラーで実装）
- キャッシュなし（常に最新情報を反映）

## 3. コンテンツ仕様

### 3.1 ファイル構造

```markdown
# Spotlight by タケユー・ウェブ株式会社

> Ruby on Rails開発に特化した技術ブログと企業サイト。技術記事、プロジェクト実績、書評などを通じて、実践的なWeb開発の知見を共有しています。

## 会社概要

タケユー・ウェブ株式会社は、Ruby on Railsを中心としたWebアプリケーション開発を専門とする企業です。DHHが提唱する「One Person Framework」の理念に共感し、最新のAIエージェント技術を活用した効率的な開発を実践しています。

- 設立: 2016年6月3日
- 代表者: 竹内雄一
- 所在地: 埼玉県さいたま市
- Ruby Association会員

## コンテンツ

### 技術記事

技術的な知見、実装方法、考察などを共有しています。

- [Articles](/articles): 技術記事、考察、アイデアなど
- 最新記事数: [動的に生成]件

### プロジェクト実績

これまでに開発・運用してきたプロジェクトを紹介しています。

- [Projects](/projects): クラウド管理システム、動画配信サービス、マッチングアプリなど
- 公開実績数: [動的に生成]件

### 書評

技術書やビジネス書のレビューを掲載しています。

- 書評記事数: [動的に生成]件

## 技術スタック

- Ruby on Rails 8.0.1
- Hotwire (Turbo + Stimulus)
- TailwindCSS
- PostgreSQL
- Kamal (デプロイメント)

## 執筆者

竹内雄一（代表取締役）
- X (Twitter): [@takeyuweb](https://x.com/takeyuweb)
- GitHub: [@takeyuweb](https://github.com/takeyuweb)

## お仕事のご依頼

### 稼働状況
[動的に生成: 現在の稼働状況を表示]

### お問い合わせ
- [お問い合わせフォーム](https://forms.gle/scwNEGrT196rFnD9A)
- お仕事のご依頼、技術相談、その他お問い合わせはフォームからお願いします

## Optional

- [Speaking](/speaking): カンファレンス登壇実績
- [Uses](/uses): 使用ツール・開発環境の紹介
- [タグ一覧](/tags): 記事のカテゴリ分類
```

### 3.2 動的生成項目

以下の項目は実行時に動的に生成される：

1. **記事数情報**
   - 総記事数
   - カテゴリ別記事数（Tech、Book Review等）
   - 最新記事のタイトルと公開日

2. **稼働状況**
   - 現在の稼働率
   - 直近3ヶ月の予約状況
   - 新規案件受付可否

3. **更新日時**
   - llms.txt生成日時
   - 最終記事更新日時

## 4. 実装詳細

### 4.1 コントローラー実装

```ruby
# app/controllers/llms_txt_controller.rb
class LlmsTxtController < ApplicationController
  def show
    @articles_count = Article.published.count
    @projects_count = Project.published.count
    @book_reviews_count = Article.tagged_with('Book Review').count
    @availability = calculate_availability
    
    render plain: generate_llms_txt, content_type: 'text/plain'
  end
  
  private
  
  def generate_llms_txt
    # テンプレートを使用してllms.txtを生成
  end
  
  def calculate_availability
    # 稼働状況を計算
  end
end
```

### 4.2 ルーティング設定

```ruby
# config/routes.rb
get 'llms.txt', to: 'llms_txt#show', format: false
```

### 4.3 テンプレート

ERBテンプレートまたはビルダーを使用して、Markdown形式のテキストを生成する。

## 5. テスト要件

### 5.1 単体テスト
- コントローラーのレスポンステスト
- 動的生成項目の正確性テスト
- Markdown形式の妥当性テスト

### 5.2 統合テスト
- エンドポイントアクセステスト
- Content-Typeの確認
- 文字エンコーディングの確認

### 5.3 受け入れテスト
- LLMツールでの読み込みテスト
- 表示内容の確認
- リンクの有効性確認

## 6. セキュリティ考慮事項

- 個人情報や機密情報を含めない
- SQLインジェクション対策（Active Recordを使用）
- 過度なアクセスによるDoS攻撃への考慮（必要に応じてレート制限を実装）

## 7. 将来の拡張性

- 多言語対応（英語版の提供）
- APIとしての拡張（JSON形式での提供）
- より詳細な統計情報の追加
- カスタマイズ可能なセクションの追加

## 8. 参考資料

- [llmstxt.org - 公式仕様](https://llmstxt.org/)
- [Rails 8.0.1 ガイド](https://guides.rubyonrails.org/)
- [ADR-016: llms.txt提供機能の実装](/docs/adr/016_llms_txt_提供機能の実装.md)