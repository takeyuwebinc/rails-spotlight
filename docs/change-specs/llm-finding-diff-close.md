# ChangeSpec: LLM層品質所見の自動クローズを差分判定に変更

## 変更の目的

llm 層の再評価は旧未処理所見を一律 obsolete で閉じるため、エージェントが所見を見て本文を修正しても addressed が記録されず、誤検知率の分母から修正実績が漏れる。SPOTLIGHT-RAILS-48 の決定に基づき、rule 層が既に行っている差分判定（新評価に同 code が無い → addressed、有る → obsolete）へ揃える。

## 現状

- rule 層（`AdrManagement::CheckAdrQuality#close_previous_open_findings`）は、旧未処理所見の code を今回の検出結果と突き合わせ、検出されなくなった code を addressed、残りを obsolete でクローズしている
- llm 層（`AdrManagement::AssessAdrQuality#close_previous_open_findings`）は、旧未処理所見を一律 obsolete でクローズしている（`close_open_findings!(result: "obsolete")` のみ）
- 処理結果の記録は `QualityAssessment#close_open_findings!`（`only_codes` による code 絞り込み対応済み）が担う。`FINDING_RESULTS` は addressed / dismissed / obsolete の3値
- ADR の失効遷移時は `Adr#close_quality_findings_on_retirement` が両層の未処理所見を obsolete で一括クローズする
- 誤検知率の集計は `QualityAssessment.findings_summary`。dismissed_rate = dismissed / (addressed + dismissed) で、obsolete は分母に含めない
- 既存テスト `spec/actions/adr_management/assess_adr_quality_spec.rb` に「本文変更後の再評価で旧 llm 所見が obsolete になる」の検証がある（変更対象の挙動）
- 同一本文（指紋一致）の llm 再評価はスキップされる。指紋の照合対象は過去の**全** llm 評価であり最新版に限らないため、本文を過去の版と同一内容に戻した場合も再評価はスキップされ、その間の版の未処理所見は差分判定の機会を持たない（この挙動は本変更のスコープ外でそのまま維持する）

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| `app/actions/adr_management/assess_adr_quality.rb` | llm 層の再評価と旧所見クローズ（変更対象） |
| `app/actions/adr_management/check_adr_quality.rb` | rule 層の差分判定クローズ（揃える先。共通化の対象） |
| `app/models/adr_management/quality_assessment.rb` | 所見の処理結果記録と誤検知率集計。共通差分判定メソッドの新設先（変更対象） |
| `app/models/adr_management/adr.rb` | 失効遷移時の一括 obsolete クローズ（挙動保証の対象。変更しない） |
| `spec/actions/adr_management/assess_adr_quality_spec.rb` | llm 層の既存テスト（obsolete 期待の修正対象） |
| `spec/actions/adr_management/check_adr_quality_spec.rb` | rule 層の既存テスト（共通化のリグレッション検知） |
| `spec/models/adr_management/quality_assessment_spec.rb` | 共通差分判定メソッドの単体テスト追加先。失効時一括 obsolete の既存テストもここ |

## 変更内容

- **追加**: 差分判定クローズの共通処理を `QualityAssessment` に切り出す（例: 「旧未処理所見のうち新評価の code 集合に無いものを addressed、有るものを obsolete で閉じる」を層のスコープと新 findings を受けて実行するメソッド）。判定ルールが rule 層・llm 層の2箇所に重複しないようにする（同じビジネスルールの重複＝機能結合の回避）
- **変更**: `AssessAdrQuality#close_previous_open_findings` を共通処理の呼び出しに置き換え、一律 obsolete を差分判定に変更する
- **変更**: `CheckAdrQuality#close_previous_open_findings` を共通処理の呼び出しに置き換える（挙動は変えない）
- **変更**: `assess_adr_quality_spec.rb` の「一律 obsolete」期待を差分判定の期待（解消 code → addressed / 継続 code → obsolete）に修正し、混在ケースを追加する
- **変更**: 変更後の事実と食い違うコメントを更新する。`AssessAdrQuality#close_previous_open_findings` の「失効として閉じ、誤検知率の集計から除外する」（addressed は分母に入るようになる）と、`findings_summary` の「人が処理した所見（addressed + dismissed）」（機械判定の addressed も含まれる）
- 失効遷移時の一括 obsolete（`close_quality_findings_on_retirement`）、`FINDING_RESULTS` の3値、`findings_summary` の定義は変更しない

## 採用した実装パターン

| # | 判断ポイント | 採用案 | 関連 ADR |
|---|------------|--------|---------|
| 1 | llm 所見の修正実績の記録方式 | rule 層と同じ差分判定・判定値も addressed をそのまま使用 | SPOTLIGHT-RAILS-48 |

## 結合への影響

新たな結合点は両 Action から共通差分判定メソッド（QualityAssessment 内）への参照のみで、同一コンテキスト内に閉じる。設計条件は「差分判定ルールの実体を1箇所に置く」こと。llm 層に判定を素朴に写すと、参照関係のない同一ビジネスルールの重複（機能結合）が2層に生まれるため、共通化を変更内容に含めている。

## 影響範囲

- llm 所見の自動クローズ結果（obsolete → addressed/obsolete の差分判定）。誤検知率の分母に llm 層の機械判定 addressed が加わる（rule 層は従来から加わっており、集計式自体は不変）
- rule 層は共通化によるコード移動のみで挙動不変（既存テストで担保）
- 管理画面・月次レポート・スキーマ・MCP ツールへの変更なし
- 既存テスト: `assess_adr_quality_spec.rb`（obsolete 期待の修正）、`check_adr_quality_spec.rb`（無修正で通ること）、`quality_assessment_spec.rb`（失効時一括 obsolete の既存検証が無修正で通ること）
- 新規テスト: 共通差分判定メソッドの単体テスト（`quality_assessment_spec.rb`）、差分判定の混在ケース（解消 code と継続 code が同居する旧評価）

## 関連 ADR

- SPOTLIGHT-RAILS-48: LLM層品質所見の自動クローズを rule 層と同じ差分判定に揃える（本変更の根拠）
- SPOTLIGHT-RAILS-46: 2層構成と処理結果記録の原則
- SPOTLIGHT-RAILS-40: 人の判断（dismissed）はレビューキュー専用のまま

## 受け入れ条件

- [ ] 本文変更後の llm 再評価（指紋不一致で実際に評価が走った場合）で、新評価に同 code の所見が無い旧未処理所見が addressed でクローズされる
- [ ] 新評価に同 code が残る旧未処理所見は obsolete でクローズされ、新しい所見が未処理として残る
- [ ] 解消 code と継続 code が混在する旧評価で、それぞれが正しい結果でクローズされる
- [ ] ADR の失効遷移時の一括 obsolete クローズが変わらない
- [ ] rule 層の既存テストが無修正で通る（共通化で挙動が変わらない）
- [ ] 差分判定ルールの実体が共通処理の1箇所にあり、rule 層・llm 層の Action 側に判定ロジックの重複が残らない
- [ ] `findings_summary` の集計仕様（dismissed_rate の定義・obsolete の除外）が変わらない
