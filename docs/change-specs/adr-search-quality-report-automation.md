# ChangeSpec: 検索品質レポートの月次自動実行と GitHub Issue 報告

## 変更の目的

検索品質の月次確認（SPOTLIGHT-RAILS-38 の再評価条件の点検根拠）が rake タスクの手動実行に依存しており、実行忘れが既定になる。SPOTLIGHT-RAILS-39 の決定に基づき、本番アプリ内で月次自動実行し GitHub Issue で報告する。

## 現状

- `adr_management:search_quality_report` rake タスクが集計と本文組み立てを内部に持ち、標準出力に表示するのみ
- Solid Queue は gem・queue DB 設定・`config/recurring.yml`（全てコメントアウト）・puma プラグイン（`SOLID_QUEUE_IN_PUMA` ゲート、config/puma.rb:38）が揃っているが、deploy.yml に環境変数がなく本番でワーカーが起動していない
- GitHub API 連携・トークンは存在しない。Sentry は導入済み（未処理例外を捕捉）
- 週次の agent-eval（GitHub Actions）が失敗時に Issue を作成する先例がある

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| lib/tasks/adr_management.rake | 集計・本文組み立てを内包する rake タスク |
| app/models/adr_management/search_log.rb | 集計元（summary） |
| app/models/adr_management/search_miss_report.rb | 集計元 |
| config/recurring.yml | Solid Queue recurring 定義（未使用） |
| config/deploy.yml | Kamal 環境変数定義 |

## 変更内容

- **追加**: `AdrManagement::BuildSearchQualityReport` Action。期間を受け取り、集計とレポート本文（Markdown）の組み立てを担う。rake タスクとジョブの二重実装を防ぐ共通化
- **追加**: `Github::IssueClient` サービス。credentials の `github.token` で GitHub API を呼び Issue を作成する（gem 追加なし、標準ライブラリの HTTP クライアントを使用。外部 API ラッパーは `Sakura::EmbeddingClient` と同じく services に置き、失敗は例外にする）
- **追加**: `AdrManagement::SearchQualityReportJob`。レポートを組み立てて Issue を作成する。トークン未設定・API 失敗は例外にして Sentry で検知する
- **変更**: rake `search_quality_report` の集計・本文組み立てを Build Action の呼び出しに置き換える（出力先は標準出力のまま）
- **変更**: `config/recurring.yml` の production に月次スケジュール（毎月1日 9時）を定義
- **変更**: `config/deploy.yml` の env に `SOLID_QUEUE_IN_PUMA: "1"` を追加（puma 内で Solid Queue を起動）

## 採用した実装パターン

| # | 判断ポイント | 採用案 | 関連 ADR |
|---|------------|--------|---------|
| 1 | 実行基盤と報告先 | Solid Queue recurring + GitHub Issue | SPOTLIGHT-RAILS-39 |
| 2 | 集計・本文の置き場所 | rake とジョブで共有する Action に集約 | 既存 Action パターンの範囲（新規 ADR 不要） |

## 結合への影響

| # | 結合点 | 変更前 強さ/距離 | 変更後 強さ/距離 | 備考 |
|---|--------|----------------|----------------|------|
| 1 | rake / Job → BuildSearchQualityReport | rake が集計ロジックを内包 | Contract(1)/同コンテキスト(1) OK | 共通化により将来の二重実装（機能結合）を予防 |
| 2 | Job → Github::IssueClient | （新規） | Contract(1)/異コンテキスト(2) OK | 汎用の Issue 作成契約のみ。ADR 管理の知識を持たせない |

## 影響範囲

- rake タスクの出力内容は同等（本文組み立ての共通化のみ）。既存 spec への影響なし
- 新規テスト: BuildSearchQualityReport Action、Github::IssueClient（HTTP スタブ）、SearchQualityReportJob（組み立て・投稿の接続、トークン未設定時の失敗）
- 本番挙動の変更: SOLID_QUEUE_IN_PUMA により puma 内で Solid Queue が起動する。既存の掲載内容管理支援エージェントの perform_later 経路もこれにより動作するようになる（副次効果）
- 運用セットアップ: GitHub fine-grained PAT（対象リポジトリの Issues: Read and write のみ）を credentials `github.token` に登録する必要がある

## 関連 ADR

- SPOTLIGHT-RAILS-39: 月次自動実行と GitHub Issue 報告（本変更の根拠）
- SPOTLIGHT-RAILS-38: 検索評価基盤（月次確認の目的）
- SPOTLIGHT-RAILS-34: Issue 通知の先例

## 受け入れ条件

- [ ] BuildSearchQualityReport が期間内の検索実行数（モード別）・0件率・取り逃がし報告（一覧含む）を含む Markdown 本文を返す
- [ ] Github::IssueClient が title・body・labels 付きで Issue 作成 API を呼び、失敗時（4xx/5xx）は例外になる
- [ ] SearchQualityReportJob がレポート本文で Issue を作成し、トークン未設定時は明確なメッセージの例外になる
- [ ] rake `search_quality_report` の出力が従来と同等の情報を含む
- [ ] recurring.yml の production に月次スケジュールが定義されている
- [ ] 既存テストが引き続き成功する
