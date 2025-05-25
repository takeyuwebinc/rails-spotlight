# ADR-012: UsesControllerへのリファクタリング

## ステータス

承認済み

## コンテキスト

`/uses` ページの機能は当初 `HomeController#uses` アクションで実装されていましたが、責任の分離とコードの整理、将来的な機能拡張を考慮して、専用のコントローラーに移動する必要がありました。

## 決定

`HomeController#uses` アクションを新しい `UsesController#index` アクションに移動し、関連するビューファイルも適切なディレクトリに移動しました。

### 主要な変更点

1. **UsesControllerの作成**
   - 専用コントローラーとして `UsesController` を新規作成
   - `index` アクションで uses items の表示ロジックを実装

2. **ルーティングの変更**
   - `get "uses" => "home#uses"` から `get "uses" => "uses#index"` に変更
   - URLパスは `/uses` のまま変更なし

3. **ビューファイルの移動**
   - `app/views/home/uses.html.erb` を `app/views/uses/index.html.erb` に移動
   - ビューの内容は変更なし

4. **HomeControllerの整理**
   - `uses` アクションを削除
   - TODOコメントを更新

## 実装詳細

### 新しいコントローラー
```ruby
class UsesController < ApplicationController
  def index
    @items_by_category = UsesItem.published
                                 .ordered
                                 .group_by(&:category)
  end
end
```

### ルーティング変更
```ruby
# 変更前
get "uses" => "home#uses"

# 変更後
get "uses" => "uses#index"
```

### ディレクトリ構造
```
app/
├── controllers/
│   ├── home_controller.rb      # uses アクション削除
│   └── uses_controller.rb      # 新規作成
└── views/
    ├── home/
    │   └── uses.html.erb       # 削除
    └── uses/
        └── index.html.erb      # 新規作成（移動）
```

## 代替案

### 1. HomeControllerに残す
- **却下理由**: 責任の分離ができず、将来的な機能拡張が困難

### 2. resourcesルーティングの使用
- **検討**: `resources :uses, only: [:index]` の使用
- **採用**: シンプルな `get` ルーティングを維持（既存パターンとの一貫性）

## 結果

### 利点
- **責任の分離**: 各コントローラーの責任が明確化
- **拡張性**: 将来的な機能追加が容易
  - `show` アクション（個別アイテムページ）
  - `category` アクション（カテゴリページ）
  - 検索・フィルタ機能
- **保守性**: コードの整理により保守が容易
- **一貫性**: 他のリソース（Articles, Projects）と同様のパターン

### 影響範囲
- **URL**: 変更なし（`/uses` のまま）
- **機能**: 変更なし（完全に同じ動作）
- **パフォーマンス**: 影響なし

### 将来的な拡張可能性
```ruby
class UsesController < ApplicationController
  def index
    # 既存の実装
  end
  
  def show
    # 個別アイテムページ
    @item = UsesItem.find_by!(slug: params[:slug])
  end
  
  def category
    # カテゴリページ
    @category = params[:category]
    @items = UsesItem.published.by_category(@category).ordered
  end
end
```

## 関連ファイル

### 変更されたファイル
- `app/controllers/uses_controller.rb` - 新規作成
- `app/controllers/home_controller.rb` - uses アクション削除
- `config/routes.rb` - ルーティング変更
- `app/views/uses/index.html.erb` - 移動（内容は同一）

### 削除されたファイル
- `app/views/home/uses.html.erb` - UsesController に移動

### 更新されたドキュメント
- `docs/specs/uses_items_feature.md` - コントローラー情報更新
- `docs/adr/011_Uses項目のMarkdown管理システム実装.md` - 関連ファイル更新
