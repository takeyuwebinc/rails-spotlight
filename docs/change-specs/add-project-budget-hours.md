# ChangeSpec: 案件予算工数と消化率の追加

## 変更の目的

現状、案件（`WorkHour::Project`）は工数実績を蓄積できるが、案件全体の予算がどこにも登録されておらず、実績が予算に対してどれだけ消化されたかを把握できない。予算超過（およびその予兆）を早期に検知し、超過時に原因となった月を追跡できるようにするため、案件単位の予算工数を登録可能にし、実績累計・消化率・月別の実績内訳を可視化する。

## 現状

- `work_hour_projects` テーブルは `code` / `name` / `client_id` / `color` / `start_date` / `end_date` / `status` を持ち、予算に相当するカラムは存在しない。
- 工数実績は `WorkHour::WorkEntry#minutes`（integer、分単位）に記録される。`WorkEntry` は `project` に `optional: true` で紐づき、案件未指定の実績（`project_name` は "その他"）も存在しうる。`WorkEntry` に集計系のクラスメソッドは存在しない。
- 案件一覧（`Admin::WorkHour::ProjectsController#index`）は `Project.includes(:client).order(:name)` で全件を名前順に表示するのみで、実績の集計は一切行っていない。フィルタ・ページネーションはない（ページネーション用の gem も導入されていない）。
- 案件詳細（`#show`）は月別見込み工数（`WorkHour::ProjectMonthlyEstimate`）を `year_month` 降順で一覧表示するのみで、実績は表示していない。
- `WorkHour::ProjectMonthlyEstimate`（`estimated_hours`、decimal(5,1)、時間単位）は既に存在するが、これは `WorkHour::AvailabilityCalculator` が月間稼働率（`BASE_HOURS = 160`、`[rate, 100].min` で 100 にキャップ、`.round` で整数化）を算出するための「月別見込み工数」であり、案件全体の予算ではない。**「見積(estimate)」という語は既にこの月別見込み工数に割り当てられている。**
- `WorkHour::CsvImporter.import_projects` は freee 形式の CSV から案件を `find_or_initialize_by(code:)` して `assign_attributes` で上書きする。上書き対象は `name` / `client` / `color` / `start_date` / `end_date` / `status` の6属性のみ。
- MCP ツール（`Tools::CreateWorkHourProjectTool` / `FindWorkHourProjectTool` / `ListWorkHourProjectsTool`）は案件の属性を明示的に文字列組み立てして出力しており、予算に相当する概念は扱っていない。カラムを追加しても自動的には露出しない。
- CSV エクスポートは工数実績（`CsvExporter.export_work_entries`）のみで、案件のエクスポートは存在しない。
- DB は全環境 sqlite3。

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| [db/schema.rb](../../db/schema.rb) | `work_hour_projects` / `work_hour_work_entries` のスキーマ定義 |
| [app/models/work_hour/project.rb](../../app/models/work_hour/project.rb) | 案件モデル。`work_entries`（`dependent: :restrict_with_error`）/ `monthly_estimates` への関連を持つ |
| [app/models/work_hour/work_entry.rb](../../app/models/work_hour/work_entry.rb) | 工数実績モデル。`minutes`（分）と `hours` 変換を持つ |
| [app/models/work_hour/project_monthly_estimate.rb](../../app/models/work_hour/project_monthly_estimate.rb) | 月別見込み工数。`estimated_hours` decimal(5,1)。今回の予算とは別概念 |
| [app/services/work_hour/availability_calculator.rb](../../app/services/work_hour/availability_calculator.rb) | 稼働率算出。月別見込み工数を参照。今回変更しない |
| [app/controllers/admin/work_hour/projects_controller.rb](../../app/controllers/admin/work_hour/projects_controller.rb) | 案件のCRUD。`index` / `show` が今回の変更対象 |
| [app/views/admin/work_hour/projects/index.html.erb](../../app/views/admin/work_hour/projects/index.html.erb) | 案件一覧テーブル（現在7列、空表示は `colspan="7"`） |
| [app/views/admin/work_hour/projects/show.html.erb](../../app/views/admin/work_hour/projects/show.html.erb) | 案件詳細。月別見込み工数の表を持つ |
| [app/views/admin/work_hour/projects/_form.html.erb](../../app/views/admin/work_hour/projects/_form.html.erb) | 案件の新規作成・編集フォーム |
| [app/services/work_hour/csv_importer.rb](../../app/services/work_hour/csv_importer.rb) | freee形式CSVからの案件・工数実績インポート |
| [spec/factories/work_hour/projects.rb](../../spec/factories/work_hour/projects.rb) | 案件の factory |

## 変更内容

### 追加

- **`work_hour_projects.budget_hours`**（decimal(7,1)、時間単位、nullable）。予算工数。単位は既存の `estimated_hours` に合わせて「時間」とする。精度は上限 99999.9 時間とし、既存の `estimated_hours` の decimal(5,1)（月別見込み用、上限 9999.9）より桁を広げる。案件全体の累計予算は月別の見込みより大きくなりうるため。
- **`WorkHour::Project` のバリデーション**: `budget_hours` は `numericality: { greater_than: 0 }, allow_nil: true`。0 時間の予算は業務上意味を持たず、消化率の 0 除算も生じるため、`nil`（未登録）か正の値のみを許容する。
- **案件別の実績集計責務**（`WorkHour::WorkEntry` のクラスメソッドとして実装）。案件ID をキーに実績分の合計を返す。案件一覧では1クエリで全案件分をまとめて取得し、案件ごとの逐次集計（N+1）を発生させない。
- **案件内の月別実績集計責務**（同じく `WorkHour::WorkEntry` のクラスメソッド）。指定案件について、対象月（`target_month`）をキーに実績分の合計を返す。案件詳細で使用する。
- **予算消化算出責務**（`app/services/work_hour/` 配下に置く値オブジェクト）。予算工数（時間）と実績分数を受け取り、実績時間・消化率・状態（正常 / 注意 / 超過）を返す。`Project` にも `WorkEntry` にも依存させない。
  - 予算が `nil` の場合、消化率は `nil`（算出不能）を返す。
  - 消化率は「実績時間 ÷ 予算工数 × 100」を四捨五入した整数。100% を超える場合も実値を返し、上限でキャップしない（`AvailabilityCalculator#calculate_rate` が 100 でキャップするのとは意図的に挙動を変える。予算管理では超過の検知が目的のため）。
  - 状態は消化率 90% 未満を「正常」、90% 以上 100% 以下を「注意」、100% 超を「超過」とする。

### 変更

- **案件フォーム**: 「予算工数」の入力欄（時間、小数可、空欄可）を追加する。ラベルは「予算工数」とし、既存の「月別見込み工数」と用語を分離する。Strong Parameters に `budget_hours` を追加する。
- **案件一覧**: 「予算工数」「実績（累計）」「消化率」の3列を追加する（7列 → 10列。空表示行の `colspan` も更新する）。実績は全期間の累計（対象月・作業日での絞り込みなし）で、小数第1位まで表示する。予算未登録の案件は消化率を「-」と表示する。消化率が 90% 以上の行は注意色、100% 超の行は警告色で強調する。
- **案件詳細**: ヘッダ下に予算・実績累計・消化率のサマリを表示する。さらに月別実績合計の表（全期間、対象月の降順。既存の月別見込み工数表と同じ並び）を追加し、超過案件の原因追跡を可能にする。既存の月別見込み工数の表は変更しない。

### スコープ外（今回対応しない）

- 案件一覧のステータス絞り込み・消化率ソート（案件件数が増えた段階で対応する）。
- MCP ツールへの予算工数の露出。
- CSV への予算工数の入出力。
- 予算の改定履歴（1案件1予算のみ保持する）。

## 採用した実装パターン

| # | 判断ポイント | 採用案 | 関連 ADR |
|---|------------|--------|---------|
| 1 | 予算の保持先 | `work_hour_projects` へのカラム追加（別テーブル化しない） | なし（既存パターン内。1案件1予算で履歴要件がないため） |
| 2 | 実績集計と消化率算出の責務配置 | 実績集計は `WorkEntry` 側のクラスメソッド（キーでグルーピングした1クエリ）。消化率は予算と実績分数のみを受け取る値オブジェクトに切り出し、`Project` には実績集計責務を持たせない（N+1 と責務の混在を回避するため） | なし（既存の `AvailabilityCalculator` と同じくサービス層に計算を置く方針の範囲内） |

ADR は起票しない。いずれも既存のアーキテクチャパターン（Rails の標準的なモデル＋サービス構成、`app/services/work_hour/` に計算責務を置く）の範囲内であり、将来の設計に長期的な制約を与える判断を含まないため。

## 結合への影響

| # | 結合点 | 変更前 強さ/距離 | 変更後 強さ/距離 | 備考 |
|---|--------|----------------|----------------|------|
| 1 | 案件一覧（`ProjectsController#index`）→ 案件別実績集計責務 | 結合なし（集計していない） | Functional(1)/同一モジュール(1) OK | 新規結合点。集計結果（案件ID→分数）のみを受け取る |
| 2 | 案件詳細（`ProjectsController#show`）→ 月別実績集計責務 | 結合なし | Functional(1)/同一モジュール(1) OK | 新規結合点。集計結果（対象月→分数）のみを受け取る |
| 3 | 案件一覧・案件詳細 → 予算消化算出責務 | 結合なし | Contract(1)/同一モジュール(1) OK | 値オブジェクトはプリミティブ（予算時間・実績分数）のみを受け取り、`Project` にも `WorkEntry` にも依存しない |
| 4 | `Project` → `WorkEntry` | Model(2)/同一モジュール(1) OK（`has_many` のみ） | 変更なし | 実績集計責務は `WorkEntry` 側に置くため、`Project` からの結合は増えない |
| 5 | `CsvImporter.import_projects` → `Project` の属性群 | Model(2)/同一モジュール(1) OK | 変更なし | `budget_hours` を `assign_attributes` の対象に含めないため、結合の強さは増えない |

不均衡（強さ > 距離）は変更前後で増えない。許容が必要な残存不均衡はない。

## 影響範囲

- **DB**: `db/migrate/` に `work_hour_projects.budget_hours`（decimal(7,1)、nullable）を追加するマイグレーションを新規作成し、`db/schema.rb` を更新する。既存レコードの `budget_hours` は `NULL` となり、消化率は「-」表示になる（一覧・詳細は破綻しない）。
- **`WorkHour::Project`**: `budget_hours` の数値バリデーション（`greater_than: 0`、`allow_nil`）を追加。
- **`WorkHour::WorkEntry`**: 案件別・月別の実績集計クラスメソッドを追加。既存の scope・インスタンスメソッドは変更しない。
- **`app/services/work_hour/`**: 予算消化算出の値オブジェクトを新規追加。
- **`Admin::WorkHour::ProjectsController`**: `index` / `show` のクエリと Strong Parameters が変わる。`create` / `update` / `destroy` のロジックは不変。
- **ビュー**: `projects/_form.html.erb`（予算工数の入力欄）、`projects/index.html.erb`（3列追加、空表示行の `colspan` を 7 → 10 に更新）、`projects/show.html.erb`（予算サマリと月別実績表の追加）。
- **`WorkHour::CsvImporter.import_projects`**: コードは変更しないが、**既存案件の再インポート時に `budget_hours` が上書き・消去されないこと**を回帰テストで担保する（現状の `assign_attributes` は6属性のみを対象とするため、そのままで要件を満たす）。
- **`WorkHour::AvailabilityCalculator` および `ProjectMonthlyEstimate`**: 変更しない。稼働率算出（トップページ / llms.txt / 管理ダッシュボード）への影響はない。
- **MCP ツール**: 変更しない。3ツールは属性を明示的に組み立てているため、カラム追加で `budget_hours` が自動露出することはない。既存の `spec/mcp/tools/work_hour_projects_tools_spec.rb` は無修正で通る想定。
- **CSV エクスポート**: 変更しない（工数実績のみが対象で、案件は対象外）。
- **管理ダッシュボードの「稼働中の案件」リスト・クライアント一覧の案件件数表示**: カラム追加のみでは破綻しないため変更しない。予算・消化率の表示は今回加えない。
- **既存テスト**: `spec/models/work_hour/project_spec.rb`（バリデーション）、`spec/models/work_hour/work_entry_spec.rb`（集計クラスメソッド）、`spec/requests/admin/work_hour/projects_spec.rb`（一覧・詳細・フォーム）の修正・追加。`spec/services/work_hour/` に予算消化算出の新規スペック。`spec/factories/work_hour/projects.rb` に `budget_hours`（デフォルトは `nil`）を追加。`spec/requests/admin/work_hour/csv_spec.rb` に予算保持の回帰ケースを追加。
- **ログ変更**: なし（個人情報・金銭・権限変更・状態変更を伴わないため、記録要件のトリガーに該当しない）。

## 関連 ADR

- なし（「採用した実装パターン」に記載のとおり、既存パターンの範囲内のため起票不要と判断）

## 受け入れ条件

### 予算の登録

- [ ] 案件の新規作成フォームで予算工数を空欄のまま保存でき、`budget_hours` が `nil` の案件が作成される
- [ ] 案件の編集フォームで予算工数（例: 120.5）を入力して保存でき、詳細・一覧に「120.5時間」と反映される
- [ ] 予算工数に 0 または負の値を入力すると保存されず、エラーメッセージが表示される

### 実績の集計

- [ ] 案件一覧に、案件ごとの実績累計（全期間の `WorkEntry#minutes` 合計の時間換算、小数第1位まで）が表示される
- [ ] 実績が1件もない案件の実績累計は 0.0 時間と表示される
- [ ] 案件未指定（`project_id` が `nil`）の実績は、どの案件の実績累計にも含まれない
- [ ] 案件を3件以上・各案件に複数の実績を用意した状態で一覧を表示したとき、案件件数を増やしても発行クエリ数が増えない（クエリカウンタで検証する）

### 消化率

- [ ] 予算が登録されている案件の消化率が「実績時間 ÷ 予算工数 × 100」の四捨五入した整数で表示される
- [ ] 予算が未登録（`nil`）の案件の消化率は「-」と表示され、例外が発生しない
- [ ] 消化率が 90% 以上 100% 以下の案件は注意色で表示される
- [ ] 消化率が 100% を超える案件は 100 でキャップされず実値（例: 120%）が表示され、警告色で強調される

### 案件詳細

- [ ] 案件詳細に予算・実績累計・消化率のサマリが表示される
- [ ] 案件詳細に、対象月ごとの実績合計が対象月の降順で表示される
- [ ] 実績が0件の案件の詳細でも、月別実績表が空状態で例外なく表示される

### 回帰

- [ ] 案件が0件のときに一覧が例外なく表示される
- [ ] 予算工数を登録済みの案件について、freee 形式の案件CSVを再インポートしても `budget_hours` が保持される
- [ ] トップページ・llms.txt・管理ダッシュボードの稼働率表示が従来どおり動作する（`AvailabilityCalculator` の挙動不変）
