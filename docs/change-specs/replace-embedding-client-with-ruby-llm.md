# ChangeSpec: Sakura::EmbeddingClient の内部実装を ruby_llm に置き換え

## 変更の目的

埋め込み API の呼び出しが Net::HTTP 手書き実装で、ruby_llm（ADR-30 で採用済み）側の設定とプロバイダ情報（エンドポイント・トークン）が二重管理になっている。内部実装を `RubyLLM.embed` に差し替えて設定を一元化し、リトライと instrumentation を得る。

## 現状

- `Sakura::EmbeddingClient`（48行）が Net::HTTP で `https://api.ai.sakura.ad.jp/v1/embeddings` を直接呼ぶ。モデルは `multilingual-e5-large`。タイムアウトは open 5秒 / read 30秒、リトライなし
- 失敗（非200・タイムアウト・接続エラー・パース失敗）は独自例外 `EmbeddingError` に集約される
- API トークンは `Rails.application.credentials.dig(:sakura, :ai_account_token)` から直接取得。同じトークンを `config/initializers/ruby_llm.rb` も `openai_api_key` として参照しており、二重管理
- 利用側は 2 Action のみ。いずれもコンストラクタで `embedding_client:` を注入でき、`EmbeddingError` を rescue してベストエフォート同期（ADR-27 の方針）を実現している
  - `AdrManagement::RefreshSearchIndex` — 埋め込み失敗時は stale のまま残して本体を成功させる
  - `AdrManagement::SearchNaturalLanguage` — stale 再試行の失敗は握りつぶし、クエリ埋め込み失敗は `search_unavailable` の failure を返す
- `query: ` / `passage: ` プレフィックスの付与は呼び出し側（Action）の責務。クライアントは関与しない
- テスト: `spec/services/sakura/embedding_client_spec.rb`（WebMock で正常系・HTTP 400・タイムアウトを検証）と、全テスト共通のデフォルトスタブ `spec/support/sakura_embedding_stub.rb`。さらに両 Action のスペックと `spec/mcp/tools/adr_search_tools_spec.rb` も、注入ではなく WebMock の `stub_request` で HTTP レベルのスタブを行っている。**計5ファイルが `Sakura::EmbeddingClient::ENDPOINT` 定数を参照して URL を組み立てている**
- ruby_llm 1.16 は OpenAI 互換 embeddings に対応済み。`RubyLLM.embed` の戻り値は `RubyLLM::Embedding` オブジェクトで、ベクトルは `#vectors` から取得する。配列入力なら `#vectors` は要素1件でも常にベクトル配列で返り、`.vectors` を呼ぶ前提で現行の `embed(texts)` の契約と一致する。`multilingual-e5-large` はモデルレジストリにないため `provider: :openai, assume_model_exists: true` の指定が必要（`ExtractAttributesTool` の `RubyLLM.chat` で同パターン使用実績あり）

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| `app/services/sakura/embedding_client.rb` | 変更対象。埋め込み API クライアント |
| `config/initializers/ruby_llm.rb` | RubyLLM グローバル設定（さくらのAI Engine 接続） |
| `app/actions/adr_management/refresh_search_index.rb` | 利用側。無変更で通すことが条件 |
| `app/actions/adr_management/search_natural_language.rb` | 利用側。無変更で通すことが条件 |
| `spec/services/sakura/embedding_client_spec.rb` | クライアントのスペック。書き換えが必要 |
| `spec/support/sakura_embedding_stub.rb` | 全テスト共通の API スタブ。`ENDPOINT` 定数を参照 |
| `spec/actions/adr_management/refresh_search_index_spec.rb` | Action スペック。`ENDPOINT` 定数で WebMock スタブ |
| `spec/actions/adr_management/search_natural_language_spec.rb` | Action スペック。`ENDPOINT` 定数で WebMock スタブ |
| `spec/mcp/tools/adr_search_tools_spec.rb` | MCP ツールスペック。`ENDPOINT` 定数で WebMock スタブ |

## 変更内容

- **変更**: `Sakura::EmbeddingClient#embed` の内部を Net::HTTP から `RubyLLM.embed`（`model: "multilingual-e5-large", provider: :openai, assume_model_exists: true`）に差し替え、戻り値は `Embedding#vectors` から取り出す。公開インターフェース（`embed(texts)` → ベクトル配列、失敗は `EmbeddingError`）は不変
- **追加**: 埋め込み専用の `RubyLLM.context`。`request_timeout` を 30 秒に設定し、チャット用途のグローバル設定（デフォルト 300 秒）と分離する
- **追加**: 例外を `EmbeddingError` へ変換するハンドリング。変換対象は `RubyLLM::Error` 系、`RubyLLM::ModelNotFoundError`・`RubyLLM::ConfigurationError`（`RubyLLM::Error` を継承せず `StandardError` 直下の点に注意）、Faraday の接続・タイムアウト・パース例外（`Faraday::TimeoutError` / `Faraday::ConnectionFailed` / `Faraday::ParsingError`）
- **削除**: Net::HTTP による HTTP 組み立て（リクエスト構築・タイムアウト定数・レスポンスパース）と、credentials からの直接トークン取得（RubyLLM 設定経由に一本化）
- **変更**: クライアントスペックを新実装に合わせて書き換える（検証観点は維持: 正常系の順序保証・HTTP 400・タイムアウト）
- **維持**: `ENDPOINT` 定数はテストスタブの参照点として残す（共通スタブ＋スペック計5ファイルが参照。実リクエスト URL が `openai_api_base` + `embeddings` で同一 URL になることはクライアントスペックで担保する）

## 採用した実装パターン

| # | 判断ポイント | 採用案 | 関連 ADR |
|---|------------|--------|---------|
| 1 | ラッパー維持で内部差し替え / Action から直接 `RubyLLM.embed` / 現状維持 | ラッパー維持で内部差し替え | SPOTLIGHT-RAILS-37 |

## 結合への影響

インターフェース・呼び出し側とも不変の内部実装置き換えのため、簡易評価のみ。

| # | 結合点 | 変更前 強さ/距離 | 変更後 強さ/距離 | 備考 |
|---|--------|----------------|----------------|------|
| 1 | `EmbeddingClient` → 埋め込み API | Contract(1)/システム外(4) | Contract(1)/システム外(4) | 不変（ワイヤフォーマット同一） |
| 2 | `EmbeddingClient` → RubyLLM グローバル設定 | なし | Contract(1)/同一システム内 | 新規。タイムアウトは専用 Context で分離し、グローバル設定への波及を遮断 |

不均衡の増加なし。

## 影響範囲

- 利用側 2 Action（`RefreshSearchIndex` / `SearchNaturalLanguage`）: 例外変換により無変更
- テスト: `ENDPOINT` 定数を維持するため、共通スタブ（`sakura_embedding_stub.rb`）・両 Action スペック・MCP ツールスペックは無変更で通る見込み。エンドポイント URL は置き換え後も同一（`openai_api_base` + `embeddings`）で、ruby_llm の Faraday アダプタはデフォルト `:net_http` のため WebMock のインターセプトは機能する
- テスト実行時間: タイムアウト・5xx をスタブするテスト（クライアントスペックの timeout ケース、両 Action スペックの 500 ケース）は、リトライ3回（interval 0.1秒・バックオフ係数2）の分だけ実行が延びる。1ケースあたり1秒未満の増加見込みで許容
- 挙動の変化: タイムアウト・5xx が最大3回リトライされる（従来は即失敗）。失敗時レイテンシと無償枠消費が増えるが、小規模利用のため許容（ADR-37 のトレードオフ、再評価条件あり）
- 性能の変化: `RubyLLM.embed` は呼び出しごとに Faraday 接続を構築する（接続の再利用なし）。現行も `Net::HTTP.start` を毎回行っており、実質差はない
- 本番 credentials・環境構築要件: 変更なし（同一トークン・同一エンドポイント）

## 関連 ADR

- SPOTLIGHT-RAILS-37: 埋め込み API クライアントの内部実装を ruby_llm に置き換え（ラッパーは維持）— 本変更の根拠
- SPOTLIGHT-RAILS-27: 自然言語検索方式の選定 — プロバイダ・モデル・プレフィックス方針は不変
- SPOTLIGHT-RAILS-30: エージェント実装基盤に ruby_llm を採用

## 受け入れ条件

- [ ] `Sakura::EmbeddingClient#embed` が複数テキストの配列に対し、入力順どおりのベクトル配列を返す（1件入力でもベクトル配列で返る）
- [ ] API が非200を返した場合・タイムアウトした場合に `EmbeddingError` が上がる（`RubyLLM::Error` 系・`ModelNotFoundError`・`ConfigurationError`・Faraday の例外が呼び出し側へ漏れない）
- [ ] リクエスト先 URL が `ENDPOINT` 定数と同一である（クライアントスペックの WebMock で担保）
- [ ] 埋め込み専用 Context の `request_timeout` が 30 秒に設定され、グローバル設定（`config/initializers/ruby_llm.rb`）は変更されていない
- [ ] クライアントスペック以外のテスト（両 Action スペック・MCP ツールスペック・共通スタブを含む全スイート）が無変更で成功する
- [ ] `embedding_client.rb` に Net::HTTP への参照と `Rails.application.credentials` の直接参照が残っていない

リトライと instrumentation（`embedding.ruby_llm` イベント）は ruby_llm のデフォルト挙動をそのまま利用するため、受け入れ条件としての個別検証は行わない。
