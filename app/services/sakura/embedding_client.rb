# frozen_string_literal: true

module Sakura
  # さくらのAI Engine の埋め込み API クライアント。
  # OpenAI 互換の /v1/embeddings（multilingual-e5-large、1024次元）を
  # RubyLLM（initializer でさくらのAI Engine を openai プロバイダとして設定）
  # 経由で呼ぶ。
  # 入力上限は 512 トークンで、超過は HTTP 400 になる（API 側での切り詰めはない）。
  # クエリ/文書のプレフィックス（"query: " / "passage: "）はサーバ側で
  # 付与されないため、呼び出し側が付与する。
  class EmbeddingClient
    class EmbeddingError < StandardError; end

    # 実際のリクエスト先（RubyLLM の openai_api_base + "embeddings"）。
    # テストの WebMock スタブはこの定数を参照して URL を組み立てる
    ENDPOINT = URI("https://api.ai.sakura.ad.jp/v1/embeddings")
    MODEL = "multilingual-e5-large"
    # 検索はユーザー対面の同期呼び出しのため、チャット用途のグローバル設定
    # （request_timeout 300秒）より短いタイムアウトを埋め込み専用に使う
    REQUEST_TIMEOUT = 30

    # texts: String の配列。対応するベクトル（Float 配列）の配列を返す。
    # 失敗（API エラー・タイムアウト・接続エラー・設定不備）は EmbeddingError にまとめる。
    def embed(texts)
      # MODEL は RubyLLM のモデルレジストリに存在しないため、
      # provider 指定 + assume_model_exists でレジストリ解決を迂回する
      embedding = context.embed(texts, model: MODEL, provider: :openai, assume_model_exists: true)
      embedding.vectors
    rescue RubyLLM::Error, RubyLLM::ConfigurationError, RubyLLM::ModelNotFoundError, Faraday::Error => e
      raise EmbeddingError, "embedding API request failed: #{e.class}: #{e.message}"
    end

    private

    def context
      RubyLLM.context { |config| config.request_timeout = REQUEST_TIMEOUT }
    end
  end
end
