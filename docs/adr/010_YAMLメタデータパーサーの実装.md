# ADR 010: YAMLメタデータパーサーの実装

## ステータス

採用

## 決定日

2025-05-25

## コンテキスト

原稿（記事・プロジェクト）のメタデータ処理において、以下の課題が存在していた：

1. **手動の正規表現パース**: Article/Projectモデルで正規表現を使ってYAMLフロントマターを手動でパースしていた
2. **エラーハンドリングの不備**: YAMLパースエラーに対する適切な処理がなかった
3. **型安全性の欠如**: 文字列として処理されており、適切な型変換がなかった
4. **重複コード**: ArticleとProjectで似たようなパース処理が重複していた
5. **保守性の問題**: メタデータ形式の変更時に複数箇所の修正が必要だった

## 決定

YAMLメタデータの処理を専門に行う`MetadataParser`サービスクラスを実装し、以下の改善を行う：

### 1. 統一されたメタデータ処理
- `MetadataParser`サービスクラスによる一元化
- RubyのYAMLライブラリ（Psych）を使用した適切なパース
- Article/Project共通のメタデータ処理ロジック

### 2. 型安全性の確保
- 適切な型変換（Date、Integer、Array等）
- バリデーション機能の強化
- デフォルト値の適切な設定

### 3. エラーハンドリングの改善
- `MetadataParseError`カスタム例外クラス
- 詳細なエラーメッセージ
- 部分的な失敗に対する適切な処理

### 4. 拡張性の向上
- 新しいメタデータフィールドの追加が容易
- カテゴリ別のバリデーションルール
- 柔軟なデータ形式サポート（配列、カンマ区切り文字列等）

## 実装内容

### MetadataParserサービスクラス
```ruby
class MetadataParser < ApplicationService
  def self.parse(file_content)
    # YAML frontmatterの抽出とパース
    # 型安全な変換とバリデーション
    # カテゴリ別の処理
  end
end
```

### 対応するメタデータ形式

#### 記事（Article）
```yaml
---
title: 記事タイトル
slug: article-slug
category: article
published_date: 2025-01-15
tags: Rails, Testing, Ruby  # または配列形式
description: 記事の説明
---
```

#### プロジェクト（Project）
```yaml
---
title: プロジェクトタイトル
category: project
published_date: 2025-02-15
position: 3
icon: fa-cloud
color: blue-500
technologies: Rails, AWS, Docker  # または配列形式
---
```

### バリデーション機能
- 必須フィールドのチェック
- 型変換とフォーマット検証
- デフォルト値の設定
- カテゴリ別のルール適用

## 結果

### 改善された点
1. **コードの保守性向上**: 重複コードの削除と一元化
2. **型安全性の確保**: 適切な型変換とバリデーション
3. **エラーハンドリング**: 詳細なエラー情報と適切な例外処理
4. **拡張性**: 新しいメタデータフィールドの追加が容易
5. **テスト可能性**: 独立したサービスクラスによる単体テスト

### パフォーマンス
- YAMLライブラリの使用により、正規表現による手動パースより高速
- メモリ使用量の最適化

### 互換性
- 既存のメタデータ形式との完全な互換性を維持
- 段階的な移行が可能

## 代替案

### 1. 既存の正規表現パースの改善
- **却下理由**: 根本的な問題（型安全性、保守性）が解決されない

### 2. 外部gemの使用（例：front_matter_parser）
- **却下理由**: 依存関係の増加、カスタマイズの制限

### 3. ActiveModelを使用したメタデータクラス
- **検討**: 将来的な拡張として検討可能だが、現時点では過剰

## 影響

### 正の影響
- メタデータ処理の信頼性向上
- 開発効率の向上
- バグの減少
- 新機能追加の容易さ

### 負の影響
- 新しいサービスクラスの学習コスト（軽微）
- テストケースの追加（品質向上のため必要）

## 関連するADR

- ADR 001: ADR運用の導入
- ADR 003: rswag導入によるAPI仕様書の自動生成

## 参考資料

- [Ruby YAML Documentation](https://ruby-doc.org/stdlib-3.0.0/libdoc/yaml/rdoc/YAML.html)
- [Rails Service Objects Pattern](https://blog.appsignal.com/2020/06/17/using-service-objects-in-ruby-on-rails.html)
