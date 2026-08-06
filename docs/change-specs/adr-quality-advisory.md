# ChangeSpec: ADR登録時の品質評価（2層構成・advisory）

## 変更の目的

ADR の品質基準が配布スキルのセルフチェックにのみ存在し、サーバー側で検証されない。プロンプト指示は確率的に省略され（SPOTLIGHT-RAILS-35 で実測）、点検不能な再評価条件や決定・実装乖離が定期点検まで発見されない。SPOTLIGHT-RAILS-46 の決定に基づき、登録・更新時の品質評価を非ブロッキングの参考情報として提供する。

## 現状

- MCP ツールは `MCP::Tool` サブクラス（[app/mcp/tools/](app/mcp/tools/)）。共通基盤 [adr_management_tool_support.rb](app/mcp/tools/adr_management_tool_support.rb) の `text_response` が単一 text ブロックを返す
- `register_adr_tool` の成功応答は [register_adr_tool.rb:119-131](app/mcp/tools/register_adr_tool.rb#L119-L131) で組み立てられ、`reference_notes`（参照 ADR と番号誤記警告）を付記する慣行が既にある。`update_adr_tool` も同様（[update_adr_tool.rb:96-105](app/mcp/tools/update_adr_tool.rb#L96-L105)）
- ビジネスロジックは Action クラス（`AdrManagement::RegisterAdr` / `UpdateAdr`）に委譲されている
- `AdrManagement::Adr` の必須本文は context / decision / consequences の3つ。alternatives / reevaluation_conditions は任意（[adr.rb:63-71](app/models/adr_management/adr.rb#L63-L71)）。品質（代替案の有無・ネガティブ影響の記載・条件の形式）はサーバー側で一切検証されない
- 再評価点検は専用テーブル `adr_management_reevaluation_checks`（SPOTLIGHT-RAILS-36 の先例: 版履歴に混載しない）
- 管理画面レビューキューは実装済み（SPOTLIGHT-RAILS-40）: `/admin/adr/search_quality` に 0件検索・取り逃がし報告の処理キューがあり、`pending_review` スコープ + `reviewed_at` 更新のパターンが確立している
- 月次品質レポートは `AdrManagement::SearchQualityReportJob`（Solid Queue recurring、毎月1日）が GitHub Issue を作成する
- LLM 基盤: ruby_llm がさくらのAI Engine（OpenAI 互換）に向いている（[config/initializers/ruby_llm.rb](config/initializers/ruby_llm.rb)）。タスク別モデル割当の先例は `ContentAgent::MODEL_ASSIGNMENTS`。LLM 呼び出しは OpenTelemetry 計装済みで Sentry に集約される

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| [app/mcp/tools/register_adr_tool.rb](app/mcp/tools/register_adr_tool.rb) | 登録ツール。成功応答に層1所見を付記する変更対象 |
| [app/mcp/tools/update_adr_tool.rb](app/mcp/tools/update_adr_tool.rb) | 更新ツール。同上 |
| [app/mcp/tools/get_adr_tool.rb](app/mcp/tools/get_adr_tool.rb) | 全文参照。層2所見セクションの表示対象 |
| [app/mcp/tools/adr_management_tool_support.rb](app/mcp/tools/adr_management_tool_support.rb) | 応答フォーマット共通基盤 |
| [app/models/adr_management/adr.rb](app/models/adr_management/adr.rb) | ADR モデル（品質所見の関連追加） |
| [app/jobs/adr_management/search_quality_report_job.rb](app/jobs/adr_management/search_quality_report_job.rb) | 月次レポート（品質サマリ追記対象） |
| [app/controllers/admin/adr_management/](app/controllers/admin/adr_management/) | 管理画面レビューキューの先例（新規コントローラ追加先） |
| [config/routes.rb](config/routes.rb) | `namespace :adr_management`（L87-101）への新キュールート追加対象 |

## 変更内容

### 追加

- **層1: ルールチェック責務**（`AdrManagement::CheckAdrQuality` Action）
  - 入力: ADR の本文フィールド。出力: 所見リスト（コード・メッセージ・対象フィールド）
  - 判定項目（すべて決定的）:
    1. alternatives が空、または案が2件未満、または「現状維持」を含まない
    2. consequences にネガティブ影響の記述がない（「ネガティブ」「トレードオフ」「デメリット」等の見出し・語の不在で判定）
    3. reevaluation_conditions の各行が「〜場合」形式でない、または見直し先（「〜を検討」等）を欠く
    4. 効果・倍率表現（「N倍」「大幅」「劇的」等）の近傍に根拠語（「計測」「実測」「出典」「見込み」）がない
    5. 本文合計が上限文字数を超過（1ページ相当。閾値は定数で管理）
  - 所見メッセージは是正方法を含める（エラー応答の `next_action` 慣行に準拠）
- **層1の応答付記**: `register_adr_tool` / `update_adr_tool` の成功応答末尾に `- Quality notes:` として所見を列挙。所見ゼロなら付記しない。登録・更新は所見の有無にかかわらず成功する（非ブロッキング）
- **品質所見モデル**（`AdrManagement::QualityAssessment`、専用テーブル。SPOTLIGHT-RAILS-36 の先例に準拠し版履歴に混載しない）
  - 属性: adr への belongs_to、layer（rule / llm）、findings（json 配列: コード・メッセージ・対象フィールド・処理結果）、評価時点の ADR 版、reviewed_at、origin
  - **処理は所見（finding）単位**で記録する: 各 finding が処理結果（addressed=修正した / dismissed=誤検知として却下 / obsolete=対象 ADR の失効・再評価による自動クローズ）を持つ。全 finding 処理済みで assessment の reviewed_at が立つ。誤検知率は finding 単位の dismissed 比率で導出する（SPOTLIGHT-RAILS-46 の採用条件）
  - **所見ゼロでも評価実施を assessment として記録する**（findings は空配列）。理由: (1) 「評価済み・問題なし」と「未評価」を区別し、所見発生率の分母を観測可能にする（再評価点検が no_trigger を記録するのと同じ原理）、(2) 層2の版番号による冪等スキップは所見ゼロの assessment が残っていることを前提とする
  - 層1・層2の両所見を保存する（層1も保存しないと誤検知率の分母が観測できない）
- **層2: LLM 評価ジョブ**（`AdrManagement::AssessAdrQualityJob`）
  - 登録時および本文フィールド更新時に enqueue（**ステータスのみの更新では enqueue しない**）。評価観点: 「この ADR がないと AI が誤る具体例」の実質性、再評価条件の観測可能性（判定者・観測データを特定できるか）、決定内容がモデル既知の一般論に堕ちていないか
  - ジョブは実行時点の ADR 現在版を評価し、**同一版の llm 層 assessment が既にあればスキップ**（版番号による冪等化。連続更新時の多重評価と重複所見を防ぐ）
  - 新しい assessment を保存する際、同一 ADR の旧版に対する未処理 llm 層 finding を obsolete で自動クローズする（最新評価のみ有効。層1の自動解消と対称）
  - ruby_llm 経由でさくらのAI Engine を利用。モデルはタスク別割当定数で管理（`ContentAgent::MODEL_ASSIGNMENTS` と同方式）
  - LLM 失敗時は所見なしで縮退し `Rails.error.report`（検索ログ記録と同じベストエフォート方針）。登録・更新操作には影響しない
- **層2所見の表示**:
  - `get_adr_tool` 応答に「品質所見（未処理のみ）」セクションを追加（点検・版履歴セクションと同様の形式）
  - 管理画面に品質所見レビューキューを追加（検索品質とは独立したキュー。新規コントローラ・ビューと `config/routes.rb` の `namespace :adr_management` 配下へのルート追加。`pending_review` + 処理アクションの既存パターンに準拠）。処理アクションは「修正した」「誤検知として却下」の2種で finding の処理結果を記録
  - 月次レポート（`SearchQualityReportJob` の Issue 本文）に品質所見サマリ（新規所見数・未処理数・処理内訳と dismissed 比率＝誤検知率）を追記

### 変更

- **層1所見の自動解消**: `update_adr_tool` で本文が修正されたとき層1ルールを再評価し、解消された rule 層 finding を addressed として自動クローズする。**ステータスのみの更新では層1チェック・Quality notes 付記・自動解消のいずれも行わない**（本文が変わらないため）
- **ADR 失効時の所見クローズ**: ADR が superseded（置換登録経由）・rejected・deprecated に遷移したとき、未処理の全 finding を obsolete で自動クローズする（失効した ADR の品質レビューは無意味であり、キュー・月次サマリ・get_adr_tool 表示から除外される）
- **配布スキル（別リポジトリ takeyuweb-tools）**: adr-management スキルの登録前セルフチェックを「応答の Quality notes に対応せよ」への参照方式に改める。本リポジトリのスコープ外のため、実装完了後に別途対応

### 削除

なし

## 採用した実装パターン

| # | 判断ポイント | 採用案 | 関連 ADR |
|---|------------|--------|---------|
| 1 | 評価の提供方式（同期/非同期/ブロッキング） | 2層構成・非ブロッキング advisory | SPOTLIGHT-RAILS-46 |
| 2 | 所見の保存先 | 専用テーブル（版履歴に混載しない） | SPOTLIGHT-RAILS-36 の先例踏襲（新規 ADR 不要） |
| 3 | 人の判断の入口 | 管理画面レビューキュー＋月次 Issue | SPOTLIGHT-RAILS-40 の先例踏襲（新規 ADR 不要） |

## 結合への影響

| # | 結合点 | 変更前 強さ/距離 | 変更後 強さ/距離 | 備考 |
|---|--------|----------------|----------------|------|
| 1 | 登録/更新ツール → 品質チェック責務 | （新規） | Contract(1)/同コンテキスト(1) OK | Action 委譲の既存パターン |
| 2 | 評価ジョブ → さくらのAI Engine | （新規） | Contract(1)/システム外(4) △ | `Sakura::EmbeddingClient` と同型の既存依存。失敗時縮退で許容 |
| 3 | 月次レポート → 品質所見モデル | （新規） | Model(2)/同コンテキスト(1) OK | 既存の SearchLog 集計と同型 |

不均衡の増加なし。#2 は外部 API 依存で解消不能だが、縮退設計により影響を登録フローから遮断する。

## 影響範囲

- `register_adr_tool` / `update_adr_tool` の応答文字列が変わる（所見がある場合のみ）。既存クライアント（スキル）は自由文の応答を読むため後方互換の問題なし
- `get_adr_tool` の応答にセクションが増える（未処理所見がある場合のみ）
- マイグレーション追加: `adr_management_quality_assessments` テーブル
- 管理画面: 新規コントローラ・ビュー・ルーティング（`namespace :adr_management` 配下）の追加。認可は `Admin::BaseController` の既存パターンに乗る
- `SearchQualityReportJob` の Issue 本文に品質セクションが増える。既存の search-quality Issue を読む運用への影響は追記のみで破壊なし
- テスト: `spec/mcp/tools/adr_write_tools_spec.rb` に所見付記の検証を追加。新規: CheckAdrQuality の単体テスト（決定的ルールのため実 API 不要）、AssessAdrQualityJob のテスト（LLM はモック）、管理画面 request spec
- 既存 ADR は遡及評価しない（新規登録・更新分から適用）

## 関連 ADR

- SPOTLIGHT-RAILS-46（proposed）: 本変更の根拠。実装完了・運用開始をもって accepted へ遷移させる
- SPOTLIGHT-RAILS-35 / 36 / 38 / 40: 準拠する先例

## 受け入れ条件

- [ ] 代替案なし・再評価条件の形式不備がある ADR を register_adr_tool で登録すると、成功応答に Quality notes が含まれ、ADR 自体は登録される。rule 層の所見が quality_assessments に保存される
- [ ] 全ルールを満たす ADR の登録応答には Quality notes が含まれず、rule 層 assessment が所見ゼロ（findings 空配列）で記録される
- [ ] 登録・本文更新時に AssessAdrQualityJob が enqueue され、実行後 quality_assessments に llm 層の所見が保存される。ステータスのみの更新では enqueue されない
- [ ] 同一版に対する AssessAdrQualityJob の重複実行は評価をスキップする
- [ ] LLM 呼び出しが失敗しても登録・更新は成功し、エラーは Rails.error.report に記録される
- [ ] 未処理所見のある ADR の get_adr_tool 応答に品質所見セクションが表示され、全 finding 処理済みになると表示されない
- [ ] update_adr_tool で層1所見の指摘箇所を修正すると、該当 rule 層 finding が addressed になる。ステータスのみの更新では層1チェックが走らない
- [ ] ADR が superseded / rejected / deprecated に遷移すると、未処理 finding が obsolete でクローズされ、キューと get_adr_tool 表示から消える
- [ ] 管理画面で finding を「修正した」「誤検知として却下」のいずれかで処理でき、処理結果が記録される
- [ ] 月次レポート Issue に品質所見サマリ（新規・未処理・処理内訳と誤検知率）が含まれる

---

備考: ログ変更セクションは省略（PII・監査・権限変更に非該当）。使い勝手レビューは軽量適用 — 単一管理者向け内部 UI で既存キューのパターン踏襲のため、フル適用は省略。滞留の可視化は月次 Issue のサマリが担う。
