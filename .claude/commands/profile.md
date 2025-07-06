---
description: プロジェクトプロファイルを切り替え
usage: /project:profile <profile_name>
---

# プロジェクトプロファイルコマンド

プロファイル名を引数として受け取り、対応するプロファイル設定を適用します。

## 使用方法

```
/project:profile development
/project:profile review
/project:profile writing
```

## 利用可能なプロファイル

- `development` - 開発モード（Rails開発専用）
- `review` - レビューモード（コードレビュー専用）
- `writing` - 記事執筆モード（記事作成・編集専用）

## プロファイル設定ファイル

プロファイルの詳細設定は `.claude/profiles/` ディレクトリに配置されています：

- `.claude/profiles/development.md`
- `.claude/profiles/review.md`
- `.claude/profiles/writing.md`

## 処理フロー

1. 引数として渡されたプロファイル名を確認
2. `.claude/profiles/{profile_name}.md` ファイルを読み込み
3. YAMLメタデータからロール情報を抽出
4. 指定されたロール（persona）として動作を開始
5. プロファイル固有のツールとコンテキストを有効化

## ロール定義

各プロファイルファイルのYAMLフロントマターで定義されたロール：

- **development**: 熟練のRailsエンジニア（19年経験）
- **review**: シニアコードレビュアー（15年経験）  
- **writing**: テック系ブログサイト編集者（12年経験）

## 技術仕様

- **メタデータ形式**: YAML フロントマター
- **必須フィールド**: `role`, `experience`, `expertise`, `persona`
- **追加フィールド**: `services`, `introduction`
- **ロール適用**: コマンド実行時に該当するpersonaとして動作
- **サービス紹介**: プロファイル切り替え時に自動的に挨拶とサービス案内を実行

## サービス紹介機能

プロファイル切り替え時に以下の動作を実行：

1. **自己紹介**: 該当するロールでの挨拶
2. **サービス案内**: 提供可能なサービスの一覧表示
3. **支援内容の確認**: 具体的な作業内容の問い合わせ