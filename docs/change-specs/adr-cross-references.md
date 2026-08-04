# ChangeSpec: ADR 間参照（本文からの自動抽出とリンク化）

## 変更の目的

ADR 間の関連は現状「置換（Supersession）」しか表現できず、本文中に書かれた他 ADR への参照（例: SPOTLIGHT-RAILS-28）はリンクにも構造化データにもならない。本文中の ADR 番号参照から関連 ADR のメタデータを持ち、管理画面・MCP 出力の双方で双方向（参照している／されている）に辿れるようにする。

## 現状

- `AdrManagement::Adr` は案件（Engagement）ごとの連番で識別され、表示・URL は `display_number`（例: SPOTLIGHT-RAILS-12。案件 code 大文字化＋連番）を用いる。表示形式の組み立ては `Adr#display_number`、表示番号からの解決は `Adr.find_by_display_number!`（末尾ハイフンで code と連番に分割し、code は大文字小文字非依存で照合）に集約されている
- ADR 間の関連は置換関係のみ。`AdrManagement::Supersession`（superseding_adr_id / superseded_adr_id、superseded 側は一意）で保持し、置換関係を持つ ADR は削除不可（`dependent: :restrict_with_error`）
- 本文系フィールドは context / decision / consequences / alternatives / reevaluation_conditions / reference_links の 6 つ。管理画面の詳細画面では `render_adr_markdown` ヘルパー（Redcarpet、autolink 有効）で描画されるが、ADR 番号表記はリンク化されない
- 書き込み経路は 3 つ: `RegisterAdr`（登録。置換の一体操作を含む）、`UpdateAdr`（内容・ステータス更新）、`ChangeAdrEngagement`（所属案件の変更。番号を移動先案件で再発行）。登録・更新後は `RefreshSearchIndex` で検索チャンクを再構築する
- MCP の `get_adr_tool` は置換変遷・再評価点検・版履歴を関連情報として出力するが、置換以外の関連 ADR は出力されない
- 版履歴（`AdrRevision`）は `Adr::SNAPSHOT_ATTRIBUTES` のスナップショットを保持する

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| app/models/adr_management/adr.rb | ADR 本体。display_number の組み立て・解決、置換関係の関連定義 |
| app/models/adr_management/supersession.rb | 置換関係（既存の唯一の ADR 間関連） |
| app/actions/adr_management/register_adr.rb | 登録（置換の一体操作を含む） |
| app/actions/adr_management/update_adr.rb | 内容・ステータス更新 |
| app/actions/adr_management/change_adr_engagement.rb | 所属案件の変更（番号再発行） |
| app/mcp/tools/get_adr_tool.rb | ADR 全文の MCP 出力（置換変遷セクションあり） |
| app/mcp/tools/register_adr_tool.rb / update_adr_tool.rb | 書き込み系 MCP ツール |
| app/helpers/admin/adr_management_helper.rb | `render_adr_markdown`（Redcarpet 描画） |
| app/views/admin/adr_management/adrs/show.html.erb | 管理画面の ADR 詳細（置換変遷の表示あり） |
| db/schema.rb | adr_management_adrs / adr_management_supersessions 等 |

## 変更内容

- **追加**: 参照テーブル `adr_management_adr_references`（source_adr_id, target_adr_id。方向付き、組で一意）とモデル `AdrManagement::AdrReference`。`Adr` に順方向（referenced_adrs）・逆方向（referencing_adrs）の関連を追加する。参照は弱い関係として扱い、参照に関与していても ADR の削除は妨げない（参照レコードは両方向とも削除に追従）
- **追加**: 本文 6 フィールドから ADR 番号表記を抽出し参照テーブルへ同期する責務（`SyncAdrReferences` アクション）。抽出規則: 単語境界で区切った英数字とハイフンの最大連続列を候補トークンとし、トークン**全体**を末尾ハイフンで code＋連番に分割（`Adr.find_by_display_number!` と同一の解決ルールを共有し、重複実装しない）、code 全体が実在する案件 code に一致（大文字小文字非依存）し番号がその案件に実在する場合のみ参照として記録する。トークン内部の部分一致は行わない（例: `SPOTLIGHT-RAILS-12` は案件 `rails` が実在しても `RAILS-12` とは解釈しない）。抽出は本文プレーンテキスト全体を対象とする（コードブロック内も含む）。自己参照は記録しない
- **変更**: `RegisterAdr`・`UpdateAdr`・`ChangeAdrEngagement` の保存と**同一トランザクション内**で参照同期（参照元の既存参照を削除して再挿入）を行う。同期失敗は操作全体の失敗となり、参照テーブルが本文とずれたまま成功することはない。同一 ADR の並行更新は ADR 行の更新と同一トランザクションのため行ロックで直列化される
- **追加**: 管理画面の markdown 描画で、解決可能な ADR 番号表記を該当 ADR の詳細ページへのリンクに変換する（解決できない表記は素のテキストのまま）。変換は Redcarpet 描画**後**の HTML に対する後処理とし、テキストノードのみを対象とする（`filter_html` 有効のため描画前のテキストに HTML を注入しない。コードブロック・既存リンク内は変換しない。この結果、コードブロック内の表記は「関連 ADR には載るがリンク化されない」非対称が生じるが許容する）
- **追加**: 管理画面の ADR 詳細に「関連 ADR」セクションを表示する（参照している ADR／この ADR を参照している ADR。各行に display_number・タイトル・ステータスラベルを併記）
- **追加**: MCP `get_adr_tool` の出力に「関連 ADR」セクションを追加する（双方向、ステータス併記）
- **変更**: MCP `register_adr_tool`・`update_adr_tool` の応答に、解決できた参照（関連付け結果）を注記する。警告の対象は「code 部分が実在する案件 code に一致するが、番号がその案件に存在しない表記」のみとする（例: SPOTLIGHT-RAILS-9999 は警告、UTF-8 / SHA-256 のような実在しない code の表記は警告しない。誤発火防止）
- **追加**: 既存 ADR のバックフィル（全 ADR を対象に参照同期を一括実行）。通常のマイグレーションとして実装し、本番デプロイ時に自動実行される形とする。本文は変更しないため `RefreshSearchIndex`（埋め込み再生成）は呼ばない

関連の手動指定 API・入力欄は設けない（本文が唯一の情報源。SPOTLIGHT-RAILS-42）。

## 採用した実装パターン

| # | 判断ポイント | 採用案 | 関連 ADR |
|---|------------|--------|---------|
| 1 | 関連メタデータの保持方式（手動指定／本文自動抽出＋保存／描画時都度計算） | 本文自動抽出＋参照テーブル同期 | SPOTLIGHT-RAILS-42 |
| 2 | 参照記法（display_number 素書き／専用記法 `[[...]]`） | display_number 素書き（実在 code＋実在番号のみ解決） | SPOTLIGHT-RAILS-42 |
| 3 | 置換関係との統合／分離 | 分離（Supersession はライフサイクルを持つ強い関係、参照は情報的な弱い関係） | SPOTLIGHT-RAILS-42 |

## 結合への影響

| # | 結合点 | 変更前 強さ/距離 | 変更後 強さ/距離 | 備考 |
|---|--------|----------------|----------------|------|
| 1 | 参照同期責務 → `Adr` の表示番号解決ルール | （新規） | Contract(1)/同一コンテキスト(1) OK | `find_by_display_number!` の解決ルールを共有。抽出側に分割規則を重複実装すると機能結合（同一ビジネスルールの二重化）になるため避ける |
| 2 | 書き込みアクション 3 種 → 参照同期責務 | （新規） | Contract(1)/同一コンテキスト(1) OK | アクションから同一コンテキストの責務を呼ぶ既存パターン（`RegisterAdr`・`UpdateAdr` の `RefreshSearchIndex` 呼び出し）に類似。ただし `RefreshSearchIndex` はトランザクション外・2 アクションのみだが、参照同期はトランザクション内・3 アクションすべてで呼ぶ |
| 3 | 管理画面ヘルパー → 参照解決責務 | （新規） | Contract(1)/同一コンテキスト(2) OK | 描画時のリンク化もモデル側の解決責務を利用 |

新規結合はいずれも AdrManagement コンテキスト内・Contract 強度で、不均衡は増えない。

## 影響範囲

- DB スキーマ: 参照テーブルの追加（既存テーブルの変更なし）
- `Adr` モデル: 関連定義の追加（既存の関連・バリデーションは変更なし）。削除時の挙動が変わる（参照レコードのみ追従削除。置換の restrict は従来どおり）
- 書き込みアクション 3 種: 参照同期の呼び出し追加。既存の入出力契約（引数・戻り値・エラー）は変更なし
- 管理画面: 詳細画面のセクション追加とリンク化。`render_adr_markdown` は全本文フィールドの描画に使われるため、リンク化はその全フィールドに効く
- MCP: `get_adr_tool` の出力セクション追加、`register_adr_tool` / `update_adr_tool` の応答文言の追加。入力スキーマは変更なし
- 管理画面の登録・編集フォーム: 今回は変更なし（未解決表記の警告は MCP 応答のみ。Web フォームでの警告表示は次フェーズ候補として意図的に対象外）
- 検索インデックス・版履歴・再評価点検: 変更なし（参照は SNAPSHOT_ATTRIBUTES に含めない。本文から再導出できるため）
- 既知の制約（SPOTLIGHT-RAILS-42 の再評価条件）:
  - 参照先が後から登録された場合: 参照元 ADR が再保存されるまで、参照テーブル・リンク化の両方に現れない
  - 参照先の案件変更（番号再発行）の場合: 参照テーブルは id ベースのため維持されるが、参照元本文の旧表記は解決できずリンク化されない。関連 ADR 一覧（テーブル由来）と本文リンク（テキスト由来）が食い違って表示され得る
- テスト: モデル（AdrReference・Adr の関連）、参照同期アクション（抽出規則・警告対象の判定を含む）、書き込みアクション 3 種への追加ケース、ヘルパー（リンク化・後処理の適用範囲）、MCP ツール応答、バックフィルの各 spec を追加。既存 spec の修正は書き込みアクションの応答文言に依存するものがあれば軽微（MCP write 系 spec は include マッチャのため応答文言の追記では壊れない）

## 関連 ADR

- SPOTLIGHT-RAILS-42: ADR間参照は本文からの自動抽出で同期する（手動指定APIは設けない）— proposed（承認待ち）
- SPOTLIGHT-RAILS-28: ADR番号の表示形式を大文字（CODE-連番）に統一 — 解決ルール（大文字小文字非依存照合・display_number 集約）の前提

## 受け入れ条件

- [ ] 本文に実在する ADR 番号（例: SPOTLIGHT-RAILS-28）を含む ADR を登録すると、参照テーブルに方向付きの参照が記録される（大文字小文字の揺れも解決される）
- [ ] 本文の更新で参照の追加・削除が参照テーブルに反映される（消えた表記の参照は削除される）
- [ ] 存在しない番号・実在しない案件 code の表記は参照として記録されず、リンク化もされない
- [ ] トークン内部の部分一致では解決されない（`SPOTLIGHT-RAILS-12` は案件 `rails` が実在しても `rails` の 12 番とは解釈されない）
- [ ] 自己参照は記録されない
- [ ] 管理画面の ADR 詳細で、本文中の解決可能な ADR 番号が該当 ADR へのリンクとして描画される（コードブロック内・既存リンク内の表記はリンク化されない）
- [ ] 管理画面の ADR 詳細に、参照している ADR／参照されている ADR がステータス付きで一覧表示される
- [ ] `get_adr_tool` の出力に双方向の関連 ADR がステータス付きで含まれる
- [ ] `register_adr_tool` / `update_adr_tool` の応答に解決できた参照が注記され、実在する案件 code ＋存在しない番号の表記（例: SPOTLIGHT-RAILS-9999）には警告が含まれる。実在しない code の表記（例: UTF-8、SHA-256）には警告が出ない
- [ ] 参照同期の失敗時は登録・更新操作全体が失敗し、本文と参照テーブルがずれた状態で成功しない
- [ ] 参照されている ADR を削除でき、参照レコードだけが削除される（置換関係の削除制限は従来どおり）
- [ ] 案件変更（ChangeAdrEngagement）後、その ADR の本文参照が再同期される
- [ ] バックフィルにより既存 ADR の本文参照が参照テーブルに反映される
