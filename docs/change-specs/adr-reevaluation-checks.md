# ChangeSpec: ADR 再評価条件の点検記録

## 変更の目的

ADR の再評価条件（`reevaluation_conditions`）は表示・検索対象にはなるものの、条件が満たされたかを評価するトリガーと点検の記録がどこにも存在しない。点検記録（いつ点検し、未発火か発火疑いか、観測メモ）を残す仕組みを追加し、エージェントが条件該当事象を観測した瞬間に永続化できるようにするとともに、「N日以上未点検の accepted ADR」の絞り込みで定期スイープの差分実行を可能にする。

## 現状

- `reevaluation_conditions` は `adr_management_adrs` のフリーテキスト列。読み出し箇所は `Tools::GetAdrTool.format_adr` の全文表示、admin の詳細表示・編集フォーム、`AdrManagement::AdrChunk` のチャンク生成ソース（自然言語検索の埋め込み対象）の3系統。いずれも表示・検索用途であり、条件を点検・評価した事実を記録する仕組みはない
- 版履歴は `AdrManagement::AdrRevision`（`adr_management_adr_revisions`）にスナップショット方式で記録される（SPOTLIGHT-RAILS-26）。change_type は `created` / `updated` / `status_changed` / `engagement_changed` の4種で、各 Action のトランザクション内で `Adr#record_revision!` により明示記録する。origin は MCP 経由なら `server_context[:origin]`、admin 経由ならコントローラが渡す web origin
- `Tools::SearchAdrsTool` のキーワード・属性検索の属性フィルタは status / confidence / decided_after / decided_before / project_name の5種（ほかに検索範囲指定の engagement_code と件数の limit）。点検状況を判定するデータは存在しない
- `Tools::GetAdrTool` は本文・置換変遷・版履歴（直近10件）を表示する
- MCP ツールは `ContentServer.create` に登録される（現在35ツール中 ADR 本体系は Search / Get / Register / Update の4ツール、version 1.5.0）
- adr-management スキルは別リポジトリ（takeyuwebinc/claude-plugins、documentation プラグイン）で配布される。本変更のツールを利用する手順（参照時チェック・条件テンプレート・点検記録）はスキル側の追随変更となる

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| app/models/adr_management/adr.rb | ADR 本体。SNAPSHOT_ATTRIBUTES、record_revision!、関連の定義 |
| app/models/adr_management/adr_revision.rb | 版履歴（今回モデル自体は変更しない。責務境界の参照先） |
| app/mcp/tools/search_adrs_tool.rb | 検索ツール。属性フィルタの追加箇所 |
| app/mcp/tools/get_adr_tool.rb | 全文表示ツール。点検セクションの追加箇所 |
| app/mcp/tools/adr_management_tool_support.rb | ツール共通処理（エラー形式・origin 取得・日付パース）。既存実装で新ツールの要件を満たすため変更なし（参照のみ） |
| app/values/adr_management/operation_error.rb | エラー種別の定義。kind 一覧コメントに `check_not_allowed` を追記 |
| app/mcp/content_server.rb | MCP ツール登録 |
| app/actions/adr_management/ | 既存 Action（Register / Update 等）。新 Action の配置先・実装パターンの参照元 |

## 変更内容

- **追加**: テーブル `adr_management_reevaluation_checks` とモデル `AdrManagement::ReevaluationCheck`
  - 列: `adr_id`（NOT NULL、外部キー）、`checked_on`（date、NOT NULL）、`result`（string、NOT NULL、enum: `no_trigger` / `suspected`）、`note`（text）、`origin`（string、NOT NULL）、`created_at`
  - バリデーション: `result` の inclusion。`result: suspected` の場合 `note` 必須（観測内容のない発火疑いは報告に使えないため）
  - `Adr` に `has_many :reevaluation_checks, dependent: :delete_all` を追加
- **追加**: Action `AdrManagement::RecordReevaluationCheck`
  - 対象 ADR が `accepted` でない場合、または `reevaluation_conditions` が空の場合はエラー（新設の種別 `check_not_allowed`、原因パラメータはそれぞれ status / reevaluation_conditions、次のアクション付き）。`OperationError` の kind 一覧コメントに追記する
  - `checked_on` が未来日の場合はエラー（種別 `invalid_input`。未来日の記録は未点検フィルタの判定を長期間抑止するため許可しない）
  - 成功時に点検記録を作成する。版履歴（AdrRevision）には記録しない（SPOTLIGHT-RAILS-36）
- **追加**: MCP ツール `Tools::RecordReevaluationCheckTool`（`record_reevaluation_check_tool`）
  - 入力: `engagement_code`（必須）、`number`（必須）、`result`（必須、enum）、`note`（`suspected` 時必須）、`checked_on`（任意、YYYY-MM-DD、省略時は当日）
  - origin は `server_context` から取得（既存ツールと同一パターン）
- **変更**: `Tools::SearchAdrsTool` に `unchecked_for_days`（integer、1以上。0以下は種別 `invalid_input` のエラー）フィルタを追加
  - 定義: 「`reevaluation_conditions` が空でなく、かつ `checked_on > 本日 − N日` の点検記録が存在しない ADR」に絞り込む。一度も点検されていない ADR を含み、ちょうど N 日前の点検は「期限切れ」としてマッチする。条件が空の ADR は点検登録が不可のため対象から除外する（除外しないと永久に未点検としてマッチし続け、差分実行が収束しない）
  - 既存の属性フィルタと同様に両経路に適用する（キーワード・属性検索経路では SQL 条件、自然言語検索経路では後段フィルタ）。ただし自然言語検索経路はスコア上位 limit 件への切り詰め後にフィルタされるため網羅性がなく、定期点検の列挙にはクエリなし（キーワード・属性検索経路）での利用を前提とする。この旨と「`status: accepted` との併用を推奨」をツール説明文に記載する
  - 未点検 ADR が limit（最大30）を超える場合は既存の「他 N 件」表示に従う。点検登録した ADR は次回の検索結果から抜けるため、再実行による差分消化でページングなしに全件を処理できる
- **変更**: `Tools::SearchAdrsTool` に `check_result`（enum: `no_trigger` / `suspected`）フィルタを追加
  - 「最新の点検記録の result が指定値である ADR」に絞り込む。後から `no_trigger` が記録された ADR は `suspected` にマッチしない（疑いが解消された扱い）
  - 定期スイープのレポート作成時に、他セッション（参照時チェック等）が記録した発火疑いを案件横断で回収する経路。これがないと発火疑いは保存されるが発見されず、「発火疑いの伝達はスイープのレポートが担う」というスコープ外の前提が成立しない
- **変更**: `Tools::GetAdrTool.format_adr` に「再評価点検（新しい順、最大5件）」セクションを追加
  - 各行: 点検日・結果・メモ（あれば）。点検記録がなければセクション省略（既存の任意セクションと同一パターン）
  - 参照時チェック（スキル側手順）で過去の発火疑いを同一応答内で確認できるようにする
- **変更**: `ContentServer` にツールを登録し、version を 1.6.0 に上げる

### スコープ外（明示）

- admin 管理画面への点検履歴表示（発火疑いの人間への伝達は月次スイープのレポートが担う）
- 月次スイープエージェント自体（本変更のツール群が前提。サーバーデプロイ後に別途設定）
- adr-management スキルの改訂（参照時チェック手順・条件テンプレート・点検記録手順）。claude-plugins リポジトリ側の変更として本変更のデプロイ後に実施する。**順序制約: スキルがツールを参照するため、サーバー側デプロイが先**

## 採用した実装パターン

| # | 判断ポイント | 採用案 | 関連 ADR |
|---|------------|--------|---------|
| 1 | 点検記録の保存方式 | 専用テーブル | SPOTLIGHT-RAILS-36 |
| 2 | 点検状況フィルタのインターフェース | `search_adrs_tool` への `unchecked_for_days` / `check_result` パラメータ追加（既存フィルタ群パターンの踏襲のため ADR 不要と判断） | — |

## 結合への影響

新規責務「再評価点検の記録」は adr_management コンテキスト内に閉じ、既存の Action ＋ MCP ツール＋共通サポートの構成パターンを踏襲する。新たな結合点は `ReevaluationCheck` → `Adr`（Model 結合）、および `SearchAdrsTool`・`GetAdrTool` → `ReevaluationCheck`（フィルタクエリ・点検セクション表示のための Model 結合）。いずれも同一コンテキスト内で距離が近く、不均衡は増えない。版履歴との結合を意図的に持たない（SPOTLIGHT-RAILS-36 の決定により分離）。

## 影響範囲

- 既存機能への振る舞い変更なし（検索の新フィルタ・get_adr の新セクションはいずれも追加的。`unchecked_for_days` 未指定時の検索結果、点検記録が存在しない ADR の get_adr 出力は現状と同一）
- マイグレーション1本追加（既存テーブルの変更なし）
- テスト: 新規（モデル・Action・ツールの spec）。`ContentServer` のツール数・version を検証する既存テストは存在しない（spec/requests/api/mcp_spec.rb は slide 系ツール名の include と serverInfo.name のみ検証）ため、既存テストの修正は不要
- adr-management スキル（別リポジトリ）: 本変更単体では影響なし。スキル改訂までの間、新ツールは存在するが使われないだけで害はない

## 関連 ADR

- [SPOTLIGHT-RAILS-36] 再評価条件の点検記録に専用テーブルを採用（版履歴への混載はしない）— 本変更の根拠
- [SPOTLIGHT-RAILS-26] ADR版履歴の実現方式 — 版履歴と分離する理由の背景
- [SPOTLIGHT-RAILS-27] 自然言語検索方式の選定 — 再評価条件の運用（言い換え対策）の背景

## 受け入れ条件

- [ ] accepted かつ再評価条件のある ADR に点検記録（no_trigger / suspected）を MCP ツールで登録できる。`checked_on` 省略時は当日で記録される
- [ ] suspected を note なしで登録するとエラーになり、エラー応答に種別・原因パラメータ・次のアクションが含まれる
- [ ] accepted 以外の ADR、再評価条件が空の ADR への点検登録は `check_not_allowed` の種別付きエラーになる
- [ ] `checked_on` の日付形式不正・未来日は種別付きエラーになる
- [ ] `search_adrs_tool` に `unchecked_for_days: 30` を指定すると、30日より新しい点検記録がなく再評価条件が空でない ADR（未点検の ADR を含む）のみ返る。ちょうど30日前に点検された ADR は含まれ、29日前に点検された ADR は含まれない
- [ ] 再評価条件が空の ADR は `unchecked_for_days` の結果に含まれない
- [ ] `unchecked_for_days` に 0 以下を指定すると種別付きエラーになる
- [ ] `check_result: suspected` を指定すると、最新の点検記録が suspected の ADR のみ返る。suspected の後に no_trigger が記録された ADR は含まれない
- [ ] `unchecked_for_days` / `check_result` は自然言語検索経路（query 指定時）でも後段フィルタとして適用される
- [ ] `get_adr_tool` の応答に点検記録が新しい順で最大5件表示され、点検記録のない ADR では従来と同一の出力になる
- [ ] ADR 削除時に点検記録も削除される
- [ ] 点検記録の origin に server_context の値が記録される
- [ ] 点検登録は版履歴（AdrRevision）にレコードを作らない
- [ ] tools/list の応答に record_reevaluation_check_tool が含まれ、serverInfo.version が 1.6.0 になる
