# タグ設定ガイドライン

## 基本方針

タグは記事に含まれる技術要素をキーワードとして整理することを目的とし、記事のカテゴライズ目的としては使用しません。開発者が技術要素で検索する際に有用となるよう設計します。

ただし、記事の性質を示す特別なタグとして、以下のカテゴリータグを1つだけ選択して付与します。

## 特別なカテゴリータグ

記事の内容に応じて、以下から1つを選択して必ず付与します：

- **Tech**: 技術記事（実装方法、設定手順、技術解説など）
- **Idea**: 考え方、情報、意見、アイデアに関する記事
- **Book Review**: 技術書・ビジネス書の書評
- **Gadget Review**: ガジェット・ハードウェアのレビュー（スマートフォン、PC、周辺機器など）

## タグ設定基準

### 1. 技術要素の特定

記事内で言及される具体的な技術、ツール、手法をキーワードとして抽出します。

**対象となる技術要素:**

- プログラミング言語（Ruby、JavaScript、Python等）
- フレームワーク（Rails、React、Vue等）
- ライブラリ・ツール（Docker、Kamal、TailwindCSS等）
- 開発手法・概念（DevOps、CI-CD、Testing等）
- インフラ・デプロイメント技術（Container-Orchestration、Zero-Downtime等）
- データベース・ストレージ（MySQL、PostgreSQL、Redis等）
- セキュリティ技術（SSL-TLS、Authentication等）

### 2. 命名規則

**スペース区切りを採用:**

- 単語間はスペース（ ）で区切る
- 例：`Rails Engine`、`Zero Downtime`、`Error Monitoring`

**大文字小文字の使い分け:**

- 固有名詞は元の表記を尊重：`TailwindCSS`、`MySQL`、`O'Reilly`
- 一般的な技術用語は適切に大文字化：`SSL/TLS`、`AI Development`

### 3. 粒度の調整

**詳細度のバランス:**

- 記事で詳しく解説されている技術には、より具体的なタグを設定
- 軽く触れる程度の技術は、より一般的なタグで対応
- 例：Rails Engineの詳細解説記事なら `Rails Engine`、軽く言及なら `Rails`

**階層的な考慮:**

- 上位概念と下位概念の両方を設定することを推奨
- 例：`Docker` と `Container Orchestration` を併用

### 4. 避けるべきタグ

**カテゴライズ目的のタグ:**

- `Tech`、`Development`、`Programming` などの汎用的な分類タグ

**主観的・感情的なタグ:**

- `Awesome`、`Best-Practice`、`Advanced` などの評価的なタグ

**記事の形式に関するタグ:**

- `Tutorial`、`Guide`、`Tips` などの記事形式タグ（特別なカテゴリータグを除く）

## タグ設定例

### 良い例

**技術記事の場合:**
```yaml
tags:
  - Tech
  - Rails
  - Rails Engine
  - TailwindCSS
  - Asset Pipeline
  - Dockerized Development
```

**書評記事の場合:**
```yaml
tags:
  - Book Review
  - LLM
  - Prompt Engineering
  - Generative AI
  - Application Development
```

**ガジェットレビューの場合:**
```yaml
tags:
  - Gadget Review
  - MacBook
  - M3 Chip
  - Performance
  - Development Environment
```

### 避けるべき例

```yaml
tags:
  - Tech
  - Web Development
  - Best Practices
  - Advanced
  - Tutorial
```

## 一貫性の保持

### 既存タグとの統一

新しい記事にタグを設定する際は、既存記事で使用されているタグとの一貫性を保ちます。

### 定期的な見直し

技術の進歩や記事の蓄積に応じて、タグ体系を定期的に見直し、必要に応じて統合・分割を行います。

## チェックリスト

記事公開前のタグ設定チェック：

- [ ] 特別なカテゴリータグ（Tech/Idea/Book Review/Gadget Review）が1つ設定されているか
- [ ] 記事の主要な技術要素がタグに反映されているか
- [ ] スペース区切りの命名規則に従っているか
- [ ] 不適切なカテゴライズ目的のタグが含まれていないか
- [ ] 既存記事との一貫性が保たれているか
- [ ] 検索時に有用なキーワードとなっているか