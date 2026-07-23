# frozen_string_literal: true

module Github
  # GitHub Issues API のクライアント。Issue の作成のみを担う。
  # 認証は fine-grained PAT（credentials の github.token。対象リポジトリの
  # Issues への書き込み権限のみを許可したものを想定）。
  # 失敗（トークン未設定・API エラー・接続エラー）は ApiError にまとめる。
  class IssueClient
    class ApiError < StandardError; end

    API_HOST = "api.github.com"
    REQUEST_TIMEOUT = 10

    def initialize(token: Rails.application.credentials.dig(:github, :token))
      @token = token
    end

    # Issue を作成し、作成された Issue の URL（html_url）を返す
    def create_issue(repo:, title:, body:, labels: [])
      raise ApiError, "GitHub token is not configured (credentials github.token)" if @token.blank?

      response = post_json("/repos/#{repo}/issues", { title: title, body: body, labels: labels })
      unless response.is_a?(Net::HTTPCreated)
        raise ApiError, "GitHub issue creation failed: HTTP #{response.code} #{response.body&.truncate(200)}"
      end

      JSON.parse(response.body).fetch("html_url")
    rescue Timeout::Error, SystemCallError, OpenSSL::SSL::SSLError, SocketError => e
      raise ApiError, "GitHub API request failed: #{e.class}: #{e.message}"
    end

    private

    def post_json(path, payload)
      http = Net::HTTP.new(API_HOST, 443)
      http.use_ssl = true
      http.open_timeout = REQUEST_TIMEOUT
      http.read_timeout = REQUEST_TIMEOUT

      request = Net::HTTP::Post.new(path, {
        "Authorization" => "Bearer #{@token}",
        "Accept" => "application/vnd.github+json",
        "X-GitHub-Api-Version" => "2022-11-28",
        "Content-Type" => "application/json"
      })
      request.body = payload.to_json
      http.request(request)
    end
  end
end
