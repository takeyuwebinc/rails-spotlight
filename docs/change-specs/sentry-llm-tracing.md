# ChangeSpec: LLM トレーシングの Sentry 集約導入（OTLP 統合 + RubyLLM 計装）

## 変更の目的

掲載内容管理支援エージェントの挙動（エージェント実行・ツール呼び出し・トークン使用量）を追跡する手段が本番ログしかない。SPOTLIGHT-RAILS-44 の決定に基づき、OpenTelemetry で LLM トレースを収集して既存 Sentry に集約し、Ruby からの gen_ai スパンで Sentry Agents Insights が機能するかを検証する。

## 現状

- LLM 呼び出しの構造: `ContentAgent::ConversationAgent`（`RubyLLM::Agent` + 6 ツール）を `GenerateResponseJob` が `agent.complete` のブロック付き＝ストリーミングで実行する。6 ツールの 1 つ `ExtractAttributesTool` は内部で独立の `RubyLLM.chat` を呼ぶ（エージェント → ツール実行 → 内部 chat の入れ子）。このほかに `Sakura::EmbeddingClient` の埋め込みがあり、主な呼び出し元は ADR 検索系（Action・MCP ツール・ジョブ）でエージェントとは別文脈。
- `config/initializers/ruby_llm.rb` で `use_new_acts_as = true`（トレースの会話 ID 自動付与の前提を満たす）。
- Sentry は `sentry-ruby` + `sentry-rails`（ともに 5.27.0）。`config/initializers/sentry.rb` で `traces_sample_rate = 1.0`（ネイティブトレーシング稼働中）、`send_default_pii = true`、`enable_logs` / `:logger` パッチ / structured_logging / breadcrumbs_logger のログ連携あり、有効環境は development / production。
- アプリコードの Sentry API 使用は `app/views/layouts/application.html.erb:61` の `Sentry.get_trace_propagation_meta` の 1 箇所のみ。受け手となるブラウザ側 Sentry JS SDK は未導入で、この meta タグに現状消費者はいない。エラー送信は `Rails.error.report` 経由（8 箇所、sentry-rails の error reporter 統合）。
- OpenTelemetry 系 gem は未導入。
- `config/initializers/filter_parameter_logging.rb` に機密キーのリスト（`:passw, :email, :secret, :token` 等）が定義済み。
- プロセス構成: 本番は `SOLID_QUEUE_IN_PUMA` により Puma 内プラグインでジョブ稼働。development は `Procfile.dev` の `bin/jobs` 独立プロセスで稼働（エージェント応答生成のトレースはこのプロセスから送信される）。
- ツールの外部通信: `WebSearchTool`（Brave Search）と `FetchUrlTool` は `Net::HTTP` を直接使用。RubyLLM の API 通信は推移的依存の Faraday を使用（Gemfile に直接記載なし）。
- 利用コストの正確な把握は `ContentAgent::ChatCost`（さくらのAI Engine 公表単価・円）が担っており、本変更の対象外。

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| Gemfile | sentry-ruby / sentry-rails（要アップグレード）。OTel 系 gem の追加先 |
| config/initializers/sentry.rb | Sentry 設定。ネイティブトレーシング撤去・OTLP 統合有効化の対象 |
| config/initializers/ruby_llm.rb | RubyLLM プロバイダ設定（変更なし、参照のみ） |
| config/initializers/filter_parameter_logging.rb | 機密キーリスト。スパン属性マスキングで流用 |
| app/views/layouts/application.html.erb | `Sentry.get_trace_propagation_meta` 呼び出し（撤去対象） |
| app/jobs/content_agent/generate_response_job.rb | ストリーミング実行経路（トレース検証対象） |
| Procfile.dev / bin/jobs | development のジョブ独立プロセス（トレース送信元） |

## 変更内容

- **変更**: `sentry-ruby` / `sentry-rails` を 6.4 以上へメジャーアップグレードする（OTLP 統合は sentry-ruby >= 6.4.0 が要件。5.x → 6.x の breaking changes を CHANGELOG で確認し、影響があれば本 ChangeSpec を更新する）。
- **追加**: Gemfile に `sentry-opentelemetry`、`opentelemetry-sdk`、`opentelemetry-exporter-otlp`、`opentelemetry-instrumentation-ruby_llm`、`opentelemetry-instrumentation-rails`、`opentelemetry-instrumentation-faraday`、`opentelemetry-instrumentation-net_http` を追加。Faraday は推移的依存だが RubyLLM の API 通信層のため計装対象とする。
- **追加**: OpenTelemetry 初期化 initializer を新設。RubyLLM・Rails 一式・Faraday・Net::HTTP の計装を有効化し、Sentry の有効環境（development / production）に合わせる。Puma プロセスと `bin/jobs` プロセスの双方で initializer 経由で初期化される（Rails 起動プロセス共通）。
- **追加**: プロンプト・出力の内容送信トグルは gem 標準の環境変数 `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` を用いる（既定: 無効。全環境同一の変数で、有効化は環境変数の設定による）。
- **追加**: エクスポート前に `gen_ai.*` の入出力・ツール引数・ツール結果属性へ `ActiveSupport::ParameterFilter`（filter_parameters 設定を流用）を適用するカスタム SpanProcessor を新設。JSON 文字列属性はパースしてキーベースでマスクし、再シリアライズする。パース不能な属性はそのまま通す。キーに紐づかない自由文（プロンプト・出力本文）は無マスクで送信されうるが、SPOTLIGHT-RAILS-44 のとおり残余リスクとして受容する（send_default_pii = true で Sentry への PII 送信は既に許容済み）。
- **変更**: `config/initializers/sentry.rb` から `traces_sample_rate` を撤去し、OTLP 統合（`config.otlp.enabled = true`）を有効化する（併用不可のため一体で行う）。エラー監視設定（DSN、send_default_pii、ログ連携 4 設定）は変えない。
- **削除**: `app/views/layouts/application.html.erb` の `Sentry.get_trace_propagation_meta` meta タグを撤去する（ネイティブトレーシング停止後は OTel トレースと相関しない値を出力しうる。ブラウザ側 SDK 未導入で消費者がいないため撤去が安全）。

## 採用した実装パターン

| # | 判断ポイント | 採用案 | 関連 ADR |
|---|------------|--------|---------|
| 1 | LLM トレースの送信先（Sentry 集約 / Langfuse 追加） | Sentry 集約（OTLP 統合） | SPOTLIGHT-RAILS-44 |
| 2 | ネイティブトレーシング撤去後の計装範囲 | Rails 一式 + HTTP クライアント + RubyLLM | SPOTLIGHT-RAILS-44 の決定範囲内（計装範囲はユーザー確認済み） |

結合強度評価は省略（観測基盤の純粋追加であり、ドメイン間の結合点を増やさない。SpanProcessor → filter_parameters はフレームワーク設定への参照に留まる）。使い勝手の現実性レビューは検証目的の導入のため省略。

## 影響範囲

- **sentry-ruby 5.x → 6.x メジャーアップグレード**: エラー監視・ログ連携の既存挙動に breaking changes が及ぶ可能性がある。アップグレード単体で既存テストと development での動作確認を先行させる。
- **Sentry のパフォーマンス画面・アラート**: トレースの生成元がネイティブ計装から OTel 計装に変わるため、トランザクション名・スパン構造が変化しうる。既存のパフォーマンスベースのアラートがあれば導入後に確認が必要（エラー監視は影響なし）。
- **`bin/jobs` 独立プロセス（development）**: エージェント応答のトレースはこのプロセスの BatchSpanProcessor から非同期送信される。通常終了時は SDK の shutdown フックで flush されるが、強制終了時は未送信スパンが失われうる（受容。検証時はプロセスを正常終了させる）。
- **計装対象の拡がり**: RubyLLM 計装は埋め込み経路（`Sakura::EmbeddingClient` → ADR 検索系）にも自動で及ぶ。追加作業はなく、本変更の検証対象はエージェント経路に限定する（埋め込みスパンは付随的な収集とする）。
- **development トレースの混在**: development も本番と同一 Sentry プロジェクトへ送信する（現行のエラー監視と同じ扱い）。内容送信トグルを development で有効化した場合、開発中のプロンプト本文が同一プロジェクトに保存される。
- **レイテンシ**: 計装追加によるオーバーヘッドが乗る（BatchSpanProcessor は非同期送信のため、エクスポートは呼び出し経路をブロックしない。導入後に体感・数値で確認する）。
- **テスト**: 既存テストへの影響は sentry 6.x アップグレード起因のものを除き想定なし（Sentry は test 環境で無効、OTel initializer も test では計装しない構成にする）。新規テストは SpanProcessor のマスキング仕様（キー一致で値がマスクされる・JSON でない属性は素通し）に対して作成する。
- **本番デプロイ**: OTLP エクスポータの向き先・認証は sentry-opentelemetry が既存 DSN から自動設定するため、環境変数・credentials の追加は不要。内容送信トグルの環境変数のみ任意で追加。

## 関連 ADR

- SPOTLIGHT-RAILS-44: LLM トレーシングは Sentry 集約（OTLP 統合 + opentelemetry-instrumentation-ruby_llm）で検証導入する
- SPOTLIGHT-RAILS-30: エージェント実装基盤に ruby_llm（RubyLLM::Agent）を採用（前提）
- SPOTLIGHT-RAILS-29: LLM プロバイダにさくらのAI Engine を採用（前提）

## 受け入れ条件

- [ ] sentry-ruby / sentry-rails 6.x へのアップグレード後、既存テストが通り、development でエラー送信・ログ連携が従来どおり動作する
- [ ] development 環境でエージェントと会話すると、Sentry のトレースに `invoke_agent` スパンとその配下の `chat` / `execute_tool` スパンが階層構造で記録される（`bin/jobs` プロセスからの送信）
- [ ] `ExtractAttributesTool` 実行時、`execute_tool` スパンの配下に内部 chat スパンが入れ子で記録される
- [ ] ストリーミング実行経路（GenerateResponseJob）の chat スパンに `gen_ai.request.stream = true` が付与される。入出力トークン数は、さくらのAI Engine がストリーミングで usage を返す場合に記録される（返さない場合は属性欠落として検証結果に記録し、対応要否を判断する）
- [ ] 内容送信トグル（`OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT`）が無効のとき、スパンにプロンプト・出力本文が含まれない
- [ ] 内容送信トグルが有効のとき、filter_parameters のキー（例: `email`, `token`）に一致するツール引数・構造化出力の値がマスクされて送信される
- [ ] Rails のリクエストトレース（コントローラ→DB クエリ）が OTel 計装経由で引き続き Sentry に記録される
- [ ] レイアウトから `Sentry.get_trace_propagation_meta` を撤去してもページ表示・既存テストに影響がない
- [ ] test 環境ではトレースが送信されない（既存テストが追加設定なしで通る）
- [ ] 検証観点: Sentry の Agents Insights（AI Agents ダッシュボード）に上記スパンが表示されるかを確認し、結果を SPOTLIGHT-RAILS-44 の再評価条件と突き合わせて記録する（表示されない場合は Langfuse 切替の再評価を起票）
