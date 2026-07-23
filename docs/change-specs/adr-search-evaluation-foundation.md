# ChangeSpec: ADR検索の評価基盤（検索ログ・ミス報告・ゴールデンクエリ回帰）

## 変更の目的

SPOTLIGHT-RAILS-27 の再評価条件「検索の取り逃がしが頻発した場合」を観測可能にし、検索実装の変更を回帰検証できるようにする。方式（検索ログ・ミス報告・ゴールデンクエリ回帰の3段構成）は SPOTLIGHT-RAILS-38 で決定済み。

## 現状

- `Tools::SearchAdrsTool.call` が検索の唯一の入口。`query` があれば `AdrManagement::SearchNaturalLanguage`（ベクトル検索）、なければキーワード/属性検索（LIKE）に分岐する排他二経路
- 検索クエリ・結果・スコアはどこにも永続化されない。取り逃がしの発生頻度を事後に確認する手段がない
- 0件時の応答（`empty_result_response`）は再検索ガイダンスを返すが、別経路で目的の ADR に到達できた事実（＝取り逃がしの実例）を記録する経路がない
- 再評価点検（`AdrManagement::ReevaluationCheck`）は専用テーブル＋専用 Action＋専用 MCP ツールの構成（SPOTLIGHT-RAILS-36）。業務イベント記録の既存パターンとして踏襲できる
- 実 API を使う品質評価は `spec/support/agent_eval.rb`（`AGENT_EVAL=1` ゲート・CI 除外）の先例がある（SPOTLIGHT-RAILS-34）。ただしエージェント評価はテスト DB のフィクスチャで完結するのに対し、検索品質評価は実 DB の ADR コーパスが必要という違いがある
- `lib/tasks/adr_management.rake` に運用タスク（`rebuild_search_index`）の置き場がある

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| app/mcp/tools/search_adrs_tool.rb | 検索 MCP ツール（両経路の入口） |
| app/actions/adr_management/search_natural_language.rb | ベクトル検索 Action |
| app/mcp/tools/adr_management_tool_support.rb | ツール共通処理（エラー形式・origin 抽出） |
| app/models/adr_management/reevaluation_check.rb | 業務イベント記録の既存パターン |
| app/mcp/content_server.rb | MCP ツールの登録箇所 |
| lib/tasks/adr_management.rake | 運用 rake タスク |

## 変更内容

### A. 検索ログ（サーバー側記録）

- **追加**: `adr_management_search_logs` テーブルと `AdrManagement::SearchLog` モデル。記録項目: 検索モード（natural_language / keyword）、query / keyword 本文、engagement_id（nullable）、適用フィルタ（JSON）、返却結果（adr_id とスコアの配列、JSON）、結果件数、origin、created_at
- **変更**: `Tools::SearchAdrsTool.call` の両経路で、応答組み立て後にログを1件記録する。記録失敗は検索応答を失敗させない（`Rails.error.report` のベストエフォート。索引更新と同じ方針）

### B. ミス報告ツール

- **追加**: `adr_management_search_miss_reports` テーブルと `AdrManagement::SearchMissReport` モデル。記録項目: 失敗したクエリ本文（必須）、到達できた ADR への参照（nullable。検索では見つからなかったが別経路で到達した場合）、到達経路・観測メモ（必須）、origin、created_at
- **追加**: `AdrManagement::ReportSearchMiss` Action と `Tools::ReportSearchMissTool`。到達 ADR は engagement_code + number で指定（未指定可: 「存在するはずだが見つけられなかった」報告）
- **変更**: `search_adrs_tool` の description と 0件時ガイダンスに「後から別経路で目的の ADR に到達した場合は report_search_miss_tool で報告する」旨を追記（配布 Skill の更新を待たずツール側で誘導する）
- **変更**: `app/mcp/content_server.rb` に新ツールを登録

### C. ゴールデンクエリ回帰テスト

- **追加**: ゴールデンクエリ定義ファイル `config/adr_search_golden_queries.yml`。各エントリは自然言語クエリと期待 ADR（engagement code + number の配列）の組。初期セットは既知の検索実績から数件を登録し、以後は検索ログ・ミス報告から人手で追加する
- **追加**: rake タスク `adr_management:search_eval`。各ゴールデンクエリで `SearchNaturalLanguage` を実行し、クエリごとの期待 ADR の順位と全体の recall@10 を出力する。実 DB の ADR コーパスと実埋め込み API を使うため、CI には組み込まず手動実行とする（改善変更の前後で実行して比較する運用）

### 運用レポート

- **追加**: rake タスク `adr_management:search_quality_report`。期間内の検索実行数（モード別）・0件率・ミス報告件数を集計して出力する。SPOTLIGHT-RAILS-38 の再評価条件（「ミス報告が月3件以上」「3ヶ月ゼロ件かつ検索実行あり」）の点検に使う

## 採用した実装パターン

| # | 判断ポイント | 採用案 | 関連 ADR |
|---|------------|--------|---------|
| 1 | 評価機構の全体方式 | 検索ログ＋ミス報告＋ゴールデンクエリ回帰の3段構成 | SPOTLIGHT-RAILS-38 |
| 2 | 記録の保存先 | 専用テーブル2本 | SPOTLIGHT-RAILS-36 のパターン踏襲（新規 ADR 不要） |
| 3 | 回帰テストの実行形態 | rake タスク＋手動実行 | SPOTLIGHT-RAILS-34 のパターンを実 DB 前提に翻案（新規 ADR 不要） |

## 結合への影響

| # | 結合点 | 変更前 強さ/距離 | 変更後 強さ/距離 | 備考 |
|---|--------|----------------|----------------|------|
| 1 | `SearchAdrsTool` → 検索ログ記録責務 | （新規） | Contract(1)/同コンテキスト(1) OK | ログ用モデルの作成メソッド呼び出しのみ。失敗を伝播させない |
| 2 | `search_eval` rake → `SearchNaturalLanguage` | （新規） | Contract(1)/同コンテキスト(1) OK | 既存 Action の公開インターフェースのみ使用 |
| 3 | ミス報告ツール → 報告 Action → 記録モデル | （新規） | Contract(1)/同コンテキスト(1) OK | ReevaluationCheck と同じ3層パターン。到達 ADR の解決は既存の engagement/adr 参照（Model(2)/同コンテキスト(1)）に留まる |
| 4 | `search_quality_report` rake → ログ・報告テーブル | （新規） | Model(2)/同コンテキスト(1) OK | 集計クエリは記録モデルのスコープとして持たせ、rake は呼ぶだけにする |

新たな不均衡は生じない。使い勝手レビュー（1.5）は内部運用ツールのため省略。

## 影響範囲

- `SearchAdrsTool` の既存応答フォーマットは変更しない（ログ記録の追記と description・ガイダンス文言の追記のみ）。既存の検索系 spec（spec/mcp/tools/adr_search_tools_spec.rb）にはログ記録の検証を追加する
- `app/mcp/content_server.rb` に `ReportSearchMissTool` を追加登録する
- 新規ファイル: マイグレーション2本（既存テーブルの変更なし）、モデル2本、Action 1本、ツール1本、rake タスク2本（`lib/tasks/adr_management.rake` に追記）、`config/adr_search_golden_queries.yml`
- 新規テスト: SearchLog / SearchMissReport モデル、ReportSearchMiss Action、ReportSearchMissTool、ログ記録の失敗が検索を失敗させないこと、rake タスクの集計・評価ロジック（埋め込みはテスト用スタブ `spec/support/sakura_embedding_stub.rb` を使用）
- 配布 Skill（takeyuweb-tools プラグイン）のミス報告手順の追記は本リポジトリ外のため対象外（ツール description での誘導で代替し、プラグイン側は別途更新）

## ログ変更

### 追加

- **検索実行ログ（adr_management_search_logs）**
  - 発生タイミング: search_adrs 実行のたび（両経路）
  - 記録項目: モード・クエリ/キーワード本文・フィルタ・結果（adr_id とスコア）・件数・origin
  - 用途: 管理者が取り逃がし分析・0件率の把握・ゴールデンクエリの種の採取に使う
- **検索ミス報告（adr_management_search_miss_reports）**
  - 発生タイミング: エージェントが検索失敗を検知して報告したとき
  - 記録項目: 失敗クエリ・到達 ADR 参照・到達経路メモ・origin
  - 用途: SPOTLIGHT-RAILS-27/38 の再評価条件の点検根拠

### 監査・記録要件

- 目的: 検索品質の観測（法令・契約上の記録義務ではない）
- 保存期間: 無期限（単一利用者・小規模。10万件超過時にローテーション検討 = SPOTLIGHT-RAILS-38 の再評価条件）
- 参照者: 管理者（開発者本人）と Coding Agent

### PIIマスキング方針

クエリ本文には取引先の機密情報が含まれうるが、保存先はローカル SQLite で外部送信はなく、ADR 本文と同一の機密性水準（SPOTLIGHT-RAILS-27 の方針）のためマスキングしない。

### 影響範囲（ログ関連）

下流の BI・監視・自動処理は存在しない（新設テーブルのため影響なし）。

## 関連 ADR

- SPOTLIGHT-RAILS-38: ADR検索の評価基盤の3段構成（本変更の根拠）
- SPOTLIGHT-RAILS-27: 自然言語検索方式の選定（再評価条件の観測対象）
- SPOTLIGHT-RAILS-36: 点検記録の専用テーブル（保存先パターンの先例）
- SPOTLIGHT-RAILS-34: 実APIシナリオ評価（評価ハーネスの先例）

## 受け入れ条件

- [ ] search_adrs 実行（自然言語・キーワード両経路）で検索ログが1件記録され、モード・クエリ/キーワード・engagement_id・適用フィルタ・結果（adr_id とスコア）・結果件数・origin が保存される
- [ ] 検索ログの記録が失敗しても検索応答は正常に返る
- [ ] report_search_miss_tool でミス報告を登録でき、到達 ADR の指定あり・なしの両方が記録できる
- [ ] 存在しない engagement_code・number を指定したミス報告は、種別・次のアクション付きのエラー応答になる
- [ ] search_adrs の description と 0件応答の両方にミス報告への誘導文言が含まれる
- [ ] ReportSearchMissTool が MCP サーバーに登録されている
- [ ] ゴールデンクエリ評価の中核ロジック（期待 ADR の順位判定・recall@10 算出）が、スタブ埋め込みを使った spec で検証されている（rake タスク本体は実 DB・実 API での手動実行）
- [ ] 検索実行数（モード別）・0件率・ミス報告件数の集計ロジックが spec で検証されている
- [ ] 既存の検索系 spec が引き続き成功する
