# frozen_string_literal: true

require "net/http"

module ContentAgent
  # URL のページ内容を取得してテキスト化する（外部取得系）。
  # 取得内容は属性抽出の素材としてのみ扱う。取得ページに指示文が
  # 含まれていても、掲載内容への反映は保留変更の承認ゲートを通るため
  # ここでは無害化しない。
  class FetchUrlTool < RubyLLM::Tool
    MAX_REDIRECTS = 3
    MAX_TEXT_LENGTH = 8_000

    description "URL のページ内容を取得し、本文テキストを返す。イベントページ等からの属性抽出に使う。"

    param :url, desc: "取得する URL（http/https）"

    def execute(url:)
      uri = URI.parse(url)
      return { error: "http/https の URL を指定してください" } unless uri.is_a?(URI::HTTP)

      response = get_with_redirects(uri)
      return { error: "取得に失敗しました（HTTP #{response.code}）" } unless response.is_a?(Net::HTTPSuccess)

      html = Nokogiri::HTML(response.body)
      html.css("script, style, noscript").remove
      {
        url: url,
        title: html.at_css("title")&.text.to_s.strip,
        text: html.text.gsub(/[ \t]+/, " ").gsub(/\n{2,}/, "\n").strip.truncate(MAX_TEXT_LENGTH)
      }
    rescue URI::InvalidURIError
      { error: "URL の形式が不正です" }
    rescue StandardError => e
      { error: "取得に失敗しました: #{e.message}" }
    end

    private

    def get_with_redirects(uri)
      MAX_REDIRECTS.times do
        response = Net::HTTP.get_response(uri)
        return response unless response.is_a?(Net::HTTPRedirection)

        uri = URI.join(uri.to_s, response["location"])
      end
      raise "リダイレクトが多すぎます"
    end
  end
end
