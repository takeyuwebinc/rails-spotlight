# frozen_string_literal: true

require "net/http"

module ContentAgent
  # Brave Search API による Web 検索（外部取得系）。イベント情報等の
  # 素材収集に使う。
  class WebSearchTool < RubyLLM::Tool
    ENDPOINT = URI.parse("https://api.search.brave.com/res/v1/web/search").freeze

    description "Web を検索し、上位結果（タイトル・URL・概要）を返す。イベント情報等の素材収集に使う。"

    param :query, desc: "検索キーワード"
    param :count, type: "integer", desc: "取得件数（既定5、最大10）", required: false

    def execute(query:, count: nil)
      count = count.nil? ? 5 : count.to_i.clamp(1, 10)

      uri = ENDPOINT.dup
      uri.query = URI.encode_www_form(q: query, count: count)
      request = Net::HTTP::Get.new(uri)
      request["X-Subscription-Token"] = Rails.application.credentials.dig(:brave, :api_key)
      request["Accept"] = "application/json"

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
      return { error: "検索に失敗しました（HTTP #{response.code}）" } unless response.is_a?(Net::HTTPSuccess)

      results = JSON.parse(response.body).dig("web", "results") || []
      {
        results: results.first(count).map do |result|
          { title: result["title"], url: result["url"], description: result["description"] }
        end
      }
    rescue StandardError => e
      { error: "検索に失敗しました: #{e.message}" }
    end
  end
end
