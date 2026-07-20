# frozen_string_literal: true

require "net/http"

module Sakura
  # さくらのAI Engine の埋め込み API クライアント。
  # OpenAI 互換の /v1/embeddings（multilingual-e5-large、1024次元）を呼ぶ。
  # 入力上限は 512 トークンで、超過は HTTP 400 になる（API 側での切り詰めはない）。
  # クエリ/文書のプレフィックス（"query: " / "passage: "）はサーバ側で
  # 付与されないため、呼び出し側が付与する。
  class EmbeddingClient
    class EmbeddingError < StandardError; end

    ENDPOINT = URI("https://api.ai.sakura.ad.jp/v1/embeddings")
    MODEL = "multilingual-e5-large"
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 30

    # texts: String の配列。対応するベクトル（Float 配列）の配列を返す。
    # 失敗（非 200・タイムアウト・接続エラー）は EmbeddingError にまとめる。
    def embed(texts)
      request = Net::HTTP::Post.new(ENDPOINT)
      request["Authorization"] = "Bearer #{api_token}"
      request["Content-Type"] = "application/json"
      request.body = { model: MODEL, input: texts }.to_json

      response = Net::HTTP.start(
        ENDPOINT.host, ENDPOINT.port,
        use_ssl: true, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT
      ) { |http| http.request(request) }

      unless response.is_a?(Net::HTTPSuccess)
        raise EmbeddingError, "embedding API returned HTTP #{response.code}: #{response.body.to_s[0, 200]}"
      end

      JSON.parse(response.body).fetch("data").map { |item| item.fetch("embedding") }
    rescue Timeout::Error, SystemCallError, SocketError, OpenSSL::SSL::SSLError, JSON::ParserError, KeyError => e
      raise EmbeddingError, "embedding API request failed: #{e.class}: #{e.message}"
    end

    private

    def api_token
      Rails.application.credentials.dig(:sakura, :ai_account_token) or
        raise EmbeddingError, "credential sakura.ai_account_token is not configured"
    end
  end
end
