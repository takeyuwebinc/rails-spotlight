# ChangeSpec: 検索品質改善ループの自動化と管理画面レビューキュー

## 変更の目的

改善ループのうち機械判定できる工程（recall 測定・数値条件の点検・レポート）を月次ジョブに集約して自動化し、意図の解釈が必要な判断（0件検索の取り逃がし判定・ゴールデンクエリ採用）だけを管理画面のアクション付きキューで人に求める。SPOTLIGHT-RAILS-40・41 の決定に基づく。

## 現状

- 月次ジョブ（`SearchQualityReportJob`）は集計と Issue 作成のみ。recall 測定（`search_eval` rake）・点検記録・0件検索の分析・ゴールデンクエリ追加はすべて手動
- ゴールデンクエリは `config/adr_search_golden_queries.yml`。実行時に追加できず、期待 ADR は code+番号の手動参照（`EvaluateGoldenQueries` が実行時に解決し、存在しなければ失敗）
- 評価結果（recall）はどこにも保存されず、推移を追えない
- `SearchLog` / `SearchMissReport` に処理状態がなく、確認済みかどうかを管理できない
- 管理画面は `Admin::BaseController`（Google OAuth セッション認証、layout "admin"、flash は layout が表示）。承認系は「親 resources only:[] + 単数 resource create を別コントローラ」パターン（pending_change_approvals）。ナビは layouts/admin.html.erb に直接列挙
- 管理系テストは request spec（`sign_in_admin` ヘルパー）が標準

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| app/jobs/adr_management/search_quality_report_job.rb | 月次ジョブ（拡張対象） |
| app/actions/adr_management/evaluate_golden_queries.rb | 評価ロジック（DB 読み込みへ変更） |
| app/actions/adr_management/build_search_quality_report.rb | レポート本文（評価・点検・キュー情報を追加） |
| app/models/adr_management/search_log.rb / search_miss_report.rb | reviewed_at と pending スコープを追加 |
| config/adr_search_golden_queries.yml | 初回インポート後に廃止（本変更では残置） |
| config/routes.rb / app/views/layouts/admin.html.erb | ルーティング・ナビ追加 |

## 変更内容

### DB

- **追加**: `adr_management_golden_queries`（adr_id 必須参照・query・note・origin・created_at）。ADR 削除に連動して削除
- **追加**: `adr_management_search_evaluations`（k・recall・details JSON・origin・created_at）。評価実行のたびに記録し推移を追う
- **変更**: `adr_management_search_logs` / `adr_management_search_miss_reports` に `reviewed_at` を追加（レビューキューの処理状態）

### 自動化（月次ジョブの拡張）

- **変更**: `EvaluateGoldenQueries` は DB の GoldenQuery（adr 直接参照）を評価対象にする。YAML 読み込み・code 解決を廃止
- **追加**: `AdrManagement::CheckSearchQualityConditions` Action。SPOTLIGHT-RAILS-38 の数値条件（月間報告3件以上／3ヶ月報告ゼロ＋検索あり／ログ10万件超／recall の前回比低下）を機械判定し、result（no_trigger/suspected）と計測値入りの note を返す
- **変更**: `SearchQualityReportJob` は 評価実行→評価保存→自動点検（`RecordReevaluationCheck` で SPOTLIGHT-RAILS-38 に記録、origin: system 系）→レポート組み立て→Issue 作成 の順に実行。評価失敗（埋め込み API 不通）はレポートに明記して縮退継続する
- **変更**: `BuildSearchQualityReport` に recall（前回比付き）・自動点検結果・レビュー待ち件数・管理画面 URL を追加
- **変更**: rake `search_eval` は DB を評価し結果を記録（origin: manual）。**追加**: rake `import_golden_queries`（YAML からの一回限りの移行。存在しない期待 ADR はスキップして報告）

### 管理画面（人の判断のキュー）

- **追加**: `GET /admin/adr/search_quality`（ダッシュボード）: 直近30日の概況・recall 推移（直近の評価履歴）・ゴールデンクエリ一覧・レビューキュー2種
- **追加**: 0件検索キューのアクション（親 resources only:[] + 単数 resource パターン）:
  - 取り逃がしとして記録（観測メモ必須・到達 ADR は code+番号で任意指定）→ `ReportSearchMiss` を実行し reviewed_at を設定
  - 問題なし → reviewed_at を設定
- **追加**: 取り逃がし報告キューのアクション:
  - ゴールデンクエリとして採用（クエリ文言は編集可、期待 ADR は報告の到達 ADR。到達 ADR なしの報告は採用不可）→ GoldenQuery を作成し reviewed_at を設定
  - 対応済みにする → reviewed_at を設定
- **変更**: 管理画面ナビに「検索品質」を追加

## 採用した実装パターン

| # | 判断ポイント | 採用案 | 関連 ADR |
|---|------------|--------|---------|
| 1 | 自動化の範囲と人の判断の求め方 | 機械判定は月次ジョブ、判断は管理画面キュー | SPOTLIGHT-RAILS-40 |
| 2 | ゴールデンクエリの保存先 | DB 移行（YAML は一回限りインポート） | SPOTLIGHT-RAILS-41 |
| 3 | 管理画面のアクション構造 | 承認ゲート UI と同じ「別コントローラの単数 resource create」 | 既存パターン踏襲（新規 ADR 不要） |

## 結合への影響

| # | 結合点 | 変更前 強さ/距離 | 変更後 強さ/距離 | 備考 |
|---|--------|----------------|----------------|------|
| 1 | Job → 評価/点検/レポート各 Action | Job は集計+Issue のみ | Contract(1)/同コンテキスト(1) OK | 判定ロジックは Action に置き、Job はオーケストレーションのみ |
| 2 | 管理画面コントローラ → 既存 Action（ReportSearchMiss 等） | MCP ツールのみが呼ぶ | Contract(1)/同コンテキスト(1) OK | ツールと管理画面が同じ Action を共有し、記録ルールの二重実装を防ぐ |
| 3 | CheckSearchQualityConditions ↔ SPOTLIGHT-RAILS-38 の閾値 | レポート文面に記載のみ | 機能結合（コード内の閾値と ADR 記載の重複） | ADR の数値条件をコードが判定する以上、不可避。定数化し ADR 番号をコメントで明示して許容 |

## 影響範囲

- 既存 spec の変更: `evaluate_golden_queries_spec`（entries 引数→DB 読み込み）、`search_quality_report_job_spec`（フロー拡張）、`build_search_quality_report_spec`（追加セクション）
- 新規テスト: GoldenQuery / SearchEvaluation モデル、pending スコープ、CheckSearchQualityConditions、管理画面 request spec（ダッシュボード・4アクション・未認証）
- MCP ツール（report_search_miss_tool 等）の挙動は不変。`search_adrs` のログ記録も不変
- 運用手順の変更: デプロイ後に `bin/rails adr_management:import_golden_queries` を一度実行（YAML→DB）。以後の追加は管理画面

## ログ変更

### 追加

- **検索評価履歴（adr_management_search_evaluations）**: 評価実行のたびに recall・詳細・実行経路を記録。管理者が推移確認・劣化検知に使う
- **点検記録の自動登録**: 既存の reevaluation_checks に origin: system 系で月次登録（スキーマ変更なし。SPOTLIGHT-RAILS-38 のみ対象）

### 影響範囲（ログ関連）

reviewed_at の追加は既存レコードに NULL で入り、既存の集計（summary・月次レポート）に影響しない。

## 関連 ADR

- SPOTLIGHT-RAILS-40（自動化方針・本変更の根拠）/ SPOTLIGHT-RAILS-41（DB 移行）
- SPOTLIGHT-RAILS-38（数値条件の出典）/ SPOTLIGHT-RAILS-39（月次ジョブ）/ SPOTLIGHT-RAILS-31（承認ゲート UI 先例）

## 受け入れ条件

- [ ] 月次ジョブが 評価→評価保存→SPOTLIGHT-RAILS-38 への点検自動記録→Issue 作成 を一連で実行する
- [ ] 数値条件の判定: 月間報告3件以上・3ヶ月ゼロ＋検索あり・ログ10万件超・recall 前回比低下のいずれかで suspected（計測値入り note）、いずれもなければ no_trigger
- [ ] 評価失敗時もレポートは発行され、失敗が本文に明記される
- [ ] Issue 本文に recall・自動点検結果・レビュー待ち件数・管理画面 URL が含まれる
- [ ] `/admin/adr/search_quality` が概況・recall 推移・ゴールデンクエリ・2つのキューを表示する（未認証はログインへリダイレクト）
- [ ] 0件検索を「取り逃がしとして記録」すると SearchMissReport が作成され、キューから消える。「問題なし」でも消える
- [ ] 取り逃がし報告を「ゴールデンクエリとして採用」すると GoldenQuery が作成され、キューから消える。到達 ADR なしの報告は採用できない
- [ ] `import_golden_queries` が YAML の期待ペアを DB に移行し、再実行しても重複しない
- [ ] 既存テストが引き続き成功する
