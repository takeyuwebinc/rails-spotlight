# Claude Code ルール設定

## コーディングスタイル

- コメントは最小限に（業務知識やワークアラウンドなど、コードから読み取れない理由のみ）
- YARDでメソッドドキュメンテーション
- gem の利用は最低限
- メタプログラミング禁止（可読性低下のため）

詳細: .claude/coding/style.md

## Rails

- Rails標準機能を使用
- Controller にロジック記述禁止
- ActiveRecord リレーションでStrict Loading使用
- 新しい抽象化レイヤーは基底クラス作成（ApplicationService等）

詳細: .claude/frameworks/rails.md

## TailwindCSS

- Tailwind CSS でスタイリング
- Tailwind Plus 利用可能

詳細: .claude/frameworks/tailwindcss.md

## テスト

- ビジネスロジックのユニットテスト必須
- Controller は Request specs でテスト
- API は rswag で OpenAPI 3.0 生成

詳細: .claude/frameworks/testing.md

## ドキュメント

- 新機能: docs/specs に仕様書作成
- 調査結果: docs/reports にレポート作成（YYYYMMDD_[内容].md）
- ADR: docs/adr に作成（主要な依存関係・アーキテクチャ変更時）

詳細: .claude/documentation/documentation.md, .claude/documentation/adr.md

## 新機能開発プロセス

- **必須**: 実装前に仕様書を docs/specs に作成
- 調査→仕様書→実装→テストの順序で進行
- 詳細な開発フローは docs/guidelines/development_process.md を参照

詳細: .claude/guidelines/development_process.md

## AI利用

- ユーザーはRails専門家（19年経験）
- Claude Code（Maxプラン）を使用
- 詳細な利用方針は .claude/tools/ai.md を参照