# Zenn Publicationの記事を表すモデル
#
# RSSフィードから取得した記事情報を抽象化し、ActiveRecord風のインターフェースを提供する。
# データベースには保存せず、外部フィードから取得したデータをキャッシュして利用する。
#
# キャッシュ戦略:
# - 通常キャッシュ: 1時間有効
# - Staleキャッシュ: 24時間有効（フィード取得失敗時のフォールバック用）
#
# @example
#   ZennArticle.all(limit: 3)
#   # => [#<ZennArticle title="...", url="...", published_at=...>, ...]
class ZennArticle
  include ActiveModel::Model
  include ActiveModel::Attributes

  FEED_URL = "https://zenn.dev/p/takeyuwebinc/feed".freeze
  CACHE_VERSION = "v2".freeze
  CACHE_KEY = "zenn_articles/#{CACHE_VERSION}".freeze
  STALE_CACHE_KEY = "zenn_articles_stale/#{CACHE_VERSION}".freeze
  CACHE_EXPIRY = 1.hour
  STALE_CACHE_EXPIRY = 24.hours
  CONNECT_TIMEOUT = 5
  READ_TIMEOUT = 10

  attribute :title, :string
  attribute :description, :string
  attribute :url, :string
  attribute :published_at, :datetime

  validates :url, format: { with: %r{\Ahttps://zenn\.dev/}, message: "must be a Zenn URL" }, allow_blank: true

  # Returns the URL only if it's a valid Zenn URL, otherwise returns nil
  # This provides an additional layer of protection against open redirect vulnerabilities
  def safe_url
    url if url&.match?(%r{\Ahttps://zenn\.dev/})
  end

  class << self
    def all(limit: nil)
      articles = fetch_from_cache || fetch_from_feed
      limit ? articles.first(limit) : articles
    end

    private

    def fetch_from_cache
      Rails.cache.read(CACHE_KEY)
    end

    def fetch_from_feed
      response = fetch_feed
      articles = parse_feed(response.body)
      cache_articles(articles)
      articles
    rescue StandardError => e
      handle_fetch_error(e)
    end

    def fetch_feed
      uri = URI.parse(FEED_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = CONNECT_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)

      raise "HTTP Error: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response
    end

    def parse_feed(xml_body)
      require "rss"
      feed = RSS::Parser.parse(xml_body, false)
      raise "Invalid RSS feed" if feed.nil?

      feed.items.map do |item|
        new(
          title: item.title,
          description: truncate_description(item.description),
          url: item.link,
          published_at: item.pubDate
        )
      end.sort_by(&:published_at).reverse
    end

    def truncate_description(text)
      return "" if text.blank?
      # HTMLタグを除去し、改行を空白に変換、先頭の空白を削除
      plain_text = text.gsub(/<[^>]+>/, "").gsub(/\s+/, " ").strip
      # 200文字で切り詰め
      plain_text.truncate(200)
    end

    def cache_articles(articles)
      Rails.cache.write(CACHE_KEY, articles, expires_in: CACHE_EXPIRY)
      Rails.cache.write(STALE_CACHE_KEY, articles, expires_in: STALE_CACHE_EXPIRY)
    end

    def handle_fetch_error(error)
      Rails.logger.warn("Failed to fetch Zenn feed: #{error.message}")
      fetch_stale_cache || []
    end

    def fetch_stale_cache
      Rails.cache.read(STALE_CACHE_KEY)
    end
  end
end
