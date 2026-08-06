# ChangeSpec: キーワード検索の表記ゆれ対策（登録時 LLM エイリアス生成）

## 変更の目的

キーワード検索は SQLite の LIKE 部分一致であり、カタカナ⇄英語の語彙ギャップを吸収できない（実事例: keyword「ペイロード」が 0 件。本文は "payload" 表記。取り逃がし報告 2026-08-04）。SPOTLIGHT-RAILS-47 の決定に基づき、ADR の登録・更新時に LLM で別表記エイリアスを生成・保存し、キーワード検索の LIKE 対象に加える。

## 現状

- キーワード検索は `Tools::SearchAdrsTool.keyword_search` が `title / context / decision / consequences / alternatives` の 5 カラムへの `LIKE` OR で実装されている（`app/mcp/tools/search_adrs_tool.rb`）
- 管理画面の ADR 一覧（`Admin::AdrManagement::AdrsController`）にも同一の 5 カラム LIKE のキーワード検索がある
- `adr_management_adrs` テーブルにエイリアス相当のカラムはない
- 登録（`AdrManagement::RegisterAdr`）・更新（`AdrManagement::UpdateAdr`）は、本文変更を契機に `AssessAdrQualityJob.perform_later` で非同期 LLM 品質評価を起動する前例がある。失敗しても本体操作は成功させる（`record_rule_quality` の rescue）。enqueue の既存テストは `spec/mcp/tools/adr_write_tools_spec.rb` にある（「ステータスのみ更新では enqueue しない」を含む）
- 更新時の起動条件は `changed & QualityAssessment::SOURCE_ATTRIBUTES`（title / context / decision / consequences / alternatives / reevaluation_conditions の 6 項目）で判定している
- LLM 呼び出しは `RubyLLM.context` + `AdrManagement.model_for(:quality_assessment)`（さくらのAI Engine、`provider: :openai, assume_model_exists: true`、タイムアウト 60 秒、応答件数上限 `MAX_FINDINGS = 10`）のパターンが `AssessAdrQuality` にある。モデル割当は `AdrManagement::MODEL_ASSIGNMENTS` に一元化されている
- 検索応答の 1 行要約は `adr_summary_line`（`adr_management_tool_support.rb`）で組み立てる。検索実行は `AdrManagement::SearchLog` に mode・results（adr_id の配列）等を記録する
- ゴールデンクエリは DB 管理（SPOTLIGHT-RAILS-41）で、自然言語検索の recall@10 を測る。keyword 経路の回帰確認手段はない（`config/adr_search_golden_queries.yml` は評価には使われず、`adr_management:import_golden_queries` による YAML→DB 移行の入力としてのみ現役）
- 既存 rake タスクの引数は ENV 方式（例: `SINCE=`）
- 開発 DB は空で、実 ADR コーパスは本番のみ

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| `app/mcp/tools/search_adrs_tool.rb` | keyword 検索の LIKE 実装・応答組み立て・検索ログ記録 |
| `app/mcp/tools/adr_management_tool_support.rb` | ADR 要約行の共通組み立て |
| `app/controllers/admin/adr_management/adrs_controller.rb` | 管理画面 ADR 一覧の同型キーワード検索 |
| `app/actions/adr_management/register_adr.rb` | 登録トランザクションと品質評価ジョブの起動 |
| `app/actions/adr_management/update_adr.rb` | 更新と本文変更時の品質評価ジョブの起動 |
| `app/actions/adr_management/assess_adr_quality.rb` | 非同期 LLM 評価の実装パターン（プロンプト・JSON パース・縮退・件数上限） |
| `app/jobs/adr_management/assess_adr_quality_job.rb` | 非同期ジョブの薄いラッパの前例 |
| `app/models/adr_management/adr.rb` | Adr モデル（SNAPSHOT_ATTRIBUTES 等の定数） |
| `app/models/adr_management.rb` | LLM モデル割当（MODEL_ASSIGNMENTS） |
| `app/models/adr_management/search_log.rb` | 検索ログ（results に一致種別を追記する対象） |

## 変更内容

- **追加**: マイグレーション `adr_management_adrs.search_aliases`（text、NULL 可）。生成済みエイリアスを改行区切りのプレーンテキストで保持する。NULL＝未生成、空文字＝生成済みでエイリアスなし、と区別する
- **追加**: `Adr::ALIAS_SOURCE_ATTRIBUTES`（title / context / decision / consequences / alternatives の 5 項目）。`QualityAssessment::SOURCE_ATTRIBUTES`（6 項目）とは別集合のため独立の定数とする
- **追加**: `AdrManagement::GenerateSearchAliases`（Action）。エイリアス源フィールドを LLM に渡し、本文中の技術用語のカタカナ⇄英語別表記のうち**本文に現れない表記のみ**を抽出して `search_aliases` に保存する。件数上限（`MAX_ALIASES`、過剰生成による適合率低下の歯止め）を設け、超過分は切り捨てる。生成 0 件は空文字で保存する。LLM 呼び出し失敗時は既存値を保持したまま縮退し、エラー報告のみ行う（`AssessAdrQuality` と同じ方針）。保存は版履歴に記録しない（`search_aliases` は派生値であり `SNAPSHOT_ATTRIBUTES` に**含めない**。版の changed_fields にジョブ由来の変更が混ざることを避ける）。モデル割当は `MODEL_ASSIGNMENTS` に `alias_generation` を追加
- **追加**: `AdrManagement::GenerateSearchAliasesJob`。`AssessAdrQualityJob` と同型の薄いラッパ（ADR 削除済みなら何もしない）
- **変更**: `RegisterAdr` の登録後処理でジョブを enqueue。`UpdateAdr` は `ALIAS_SOURCE_ATTRIBUTES` の変更時のみ enqueue。enqueue 失敗は本体操作を失敗させない
- **変更**: `SearchAdrsTool.keyword_search` の LIKE 対象に `search_aliases` を追加。本文 5 カラムに一致せず `search_aliases` のみに一致した ADR は、要約行に「エイリアス一致（本文は別表記）」の注記を付け、検索ログの results 該当エントリに一致種別（エイリアスのみ一致）を記録する（SPOTLIGHT-RAILS-47 再評価条件の観測用）
- **変更**: 管理画面 ADR 一覧のキーワード検索も LIKE 対象に `search_aliases` を追加する（MCP と同一の語彙ギャップを持つため。画面側の注記は付けない）
- **変更**: 管理画面 ADR 詳細に生成済み `search_aliases` を読み取り専用で表示する（どの語で引けるかの事後検証手段。SPOTLIGHT-RAILS-47 ポジティブ(3)）
- **変更**: `search_adrs_tool` の `keyword` パラメータ説明に、生成エイリアスも検索対象である旨を追記
- **追加**: rake タスク `adr_management:generate_search_aliases`。`search_aliases` が NULL（未生成）の ADR 全件に生成を実行する（バックフィル用。冪等）。`FORCE=1` で全件再生成（既存 rake の ENV 方式に合わせる）

## 採用した実装パターン

| # | 判断ポイント | 採用案 | 関連 ADR |
|---|------------|--------|---------|
| 1 | 表記ゆれ対策の方式（辞書 / フォールバック / 登録時生成） | 登録時 LLM エイリアス生成 | SPOTLIGHT-RAILS-47 |
| 2 | 生成タイミング（同期ベストエフォート / 非同期ジョブ） | 非同期ジョブ（SPOTLIGHT-RAILS-46 層2と同型） | SPOTLIGHT-RAILS-47 |
| 3 | 保存先（カラム追加 / 別テーブル） | `adrs` へのカラム追加（既存パターンの範囲内のため ADR 起票なし） | — |

## 結合への影響

| # | 結合点 | 変更前 強さ/距離 | 変更後 強さ/距離 | 備考 |
|---|--------|----------------|----------------|------|
| 1 | `RegisterAdr` / `UpdateAdr` → エイリアス生成ジョブ | （なし） | Model(2)/同一コンテキスト(1) OK | 既存の品質評価ジョブ起動と同型 |
| 2 | keyword 検索（MCP・管理画面） → `search_aliases` カラム | （なし） | Model(2)/同一コンテキスト(1) OK | 同一モデル内のカラム参照追加 |

不均衡の増加なし。

## 影響範囲

- MCP ツール `search_adrs_tool` の keyword 検索結果（エイリアス一致分が増える。既存の一致結果は不変）と検索ログ results のエントリ形式（一致種別の追記）
- 管理画面 ADR 一覧のキーワード検索結果・ADR 詳細画面の表示項目
- `RegisterAdr` / `UpdateAdr` のジョブ enqueue（既存の品質評価ジョブと並ぶ）
- `db/migrate/` 新規ファイルと `db/schema.rb` の更新
- 既存テスト: `spec/mcp/tools/adr_search_tools_spec.rb`（keyword 検索）、`spec/mcp/tools/adr_write_tools_spec.rb`（enqueue 検証の追加先。「ステータスのみ更新では enqueue しない」の同型追加）、`spec/requests/admin/adr_management/adrs_spec.rb`（管理画面検索・詳細表示）
- 新規テスト: `GenerateSearchAliases`（生成・0件時の空文字保存・縮退・本文既出表記の除外・件数上限）、ジョブ、rake タスク、エイリアス一致の応答注記と検索ログ記録
- デプロイ後に本番でバックフィル rake タスクの実行が必要（実コーパスは本番のみ）
- keyword 経路の効果測定は取り逃がし報告と検索ログの一致種別に委ねる（ゴールデンクエリは自然言語経路専用のまま変えない）

## 関連 ADR

- SPOTLIGHT-RAILS-47: ADR キーワード検索の表記ゆれ対策に登録時 LLM エイリアス生成を採用（本変更の根拠）
- SPOTLIGHT-RAILS-27: 検索経路の役割分担（keyword 経路は決定的・網羅的）
- SPOTLIGHT-RAILS-46: 非同期 LLM ジョブの前例（同型で実装）
- SPOTLIGHT-RAILS-42: 登録・更新時の本文からの派生データ同期の前例（同期・トランザクション内。今回は LLM 呼び出しのため非同期を選ぶ）

## 受け入れ条件

- [ ] `search_aliases` に「ペイロード」を持ち本文が "payload" 表記の ADR が、MCP の keyword「ペイロード」検索と管理画面のキーワード検索の両方でヒットする
- [ ] エイリアスのみ一致の ADR は要約行に注記が付き、検索ログの results に一致種別が記録される。本文一致の ADR には付かない
- [ ] `search_aliases` が NULL の ADR（生成ジョブ完了前）も従来通り本文一致で検索できる
- [ ] ADR 登録・エイリアス源フィールドの更新で生成ジョブが enqueue され、源フィールド以外（status 等）の更新では enqueue されない
- [ ] LLM 呼び出しが失敗しても登録・更新・生成 Action は例外にならず、既存の `search_aliases` が保持される
- [ ] 生成結果から本文に既出の表記が除外され、件数上限を超える分は切り捨てられる。生成 0 件は空文字で保存される
- [ ] `search_aliases` の保存で版履歴（revisions）が増えない
- [ ] 管理画面 ADR 詳細に生成済みエイリアスが表示される
- [ ] rake タスクが `search_aliases` NULL の ADR のみを対象に生成し、再実行しても生成済み（空文字含む）をスキップする。`FORCE=1` で全件再生成する
- [ ] 既存の keyword 検索・自然言語検索のテストが引き続き通る
