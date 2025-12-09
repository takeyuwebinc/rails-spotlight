require "rails_helper"

RSpec.describe ZennArticle do
  describe ".all" do
    let(:feed_url) { ZennArticle::FEED_URL }
    let(:sample_rss) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
          <channel>
            <title>タケユー・ウェブ株式会社のフィード</title>
            <link>https://zenn.dev/p/takeyuwebinc</link>
            <description>ZennのPublication「タケユー・ウェブ株式会社」のRSSフィード</description>
            <item>
              <title>Rails 8で始めるKamal入門</title>
              <link>https://zenn.dev/takeyuwebinc/articles/rails8-kamal-intro</link>
              <description>Rails 8から標準になったKamalについて解説します。</description>
              <pubDate>Mon, 09 Dec 2024 10:00:00 +0900</pubDate>
              <guid>https://zenn.dev/takeyuwebinc/articles/rails8-kamal-intro</guid>
              <dc:creator>takeyuweb</dc:creator>
            </item>
            <item>
              <title>Claude Codeを使った開発効率化</title>
              <link>https://zenn.dev/takeyuwebinc/articles/claude-code-dev</link>
              <description>Claude Codeを使った開発ワークフローを紹介します。</description>
              <pubDate>Sun, 08 Dec 2024 09:00:00 +0900</pubDate>
              <guid>https://zenn.dev/takeyuwebinc/articles/claude-code-dev</guid>
              <dc:creator>takeyuweb</dc:creator>
            </item>
            <item>
              <title>TailwindCSSでのダークモード実装</title>
              <link>https://zenn.dev/takeyuwebinc/articles/tailwind-dark-mode</link>
              <description>TailwindCSSでダークモードを実装する方法。</description>
              <pubDate>Sat, 07 Dec 2024 08:00:00 +0900</pubDate>
              <guid>https://zenn.dev/takeyuwebinc/articles/tailwind-dark-mode</guid>
              <dc:creator>takeyuweb</dc:creator>
            </item>
          </channel>
        </rss>
      XML
    end

    around do |example|
      # Use memory store for caching tests
      original_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
      Rails.cache = original_cache
    end

    context "when feed is fetched successfully" do
      before do
        stub_request(:get, feed_url)
          .to_return(status: 200, body: sample_rss, headers: { "Content-Type" => "application/rss+xml" })
      end

      it "returns an array of ZennArticle instances" do
        articles = described_class.all

        expect(articles).to be_an(Array)
        expect(articles.size).to eq(3)
        expect(articles).to all(be_a(ZennArticle))
      end

      it "extracts article attributes correctly" do
        articles = described_class.all
        first_article = articles.first

        expect(first_article.title).to eq("Rails 8で始めるKamal入門")
        expect(first_article.description).to eq("Rails 8から標準になったKamalについて解説します。")
        expect(first_article.url).to eq("https://zenn.dev/takeyuwebinc/articles/rails8-kamal-intro")
        expect(first_article.published_at).to be_a(Time)
      end

      it "orders articles by published_at descending" do
        articles = described_class.all

        expect(articles.first.title).to eq("Rails 8で始めるKamal入門")
        expect(articles.last.title).to eq("TailwindCSSでのダークモード実装")
      end

      it "caches the result" do
        # Ensure cache is clear
        Rails.cache.delete(ZennArticle::CACHE_KEY)
        Rails.cache.delete(ZennArticle::STALE_CACHE_KEY)

        described_class.all
        described_class.all

        expect(a_request(:get, feed_url)).to have_been_made.once
      end
    end

    context "when limit option is provided" do
      before do
        stub_request(:get, feed_url)
          .to_return(status: 200, body: sample_rss, headers: { "Content-Type" => "application/rss+xml" })
      end

      it "returns limited number of articles" do
        articles = described_class.all(limit: 2)

        expect(articles.size).to eq(2)
        expect(articles.first.title).to eq("Rails 8で始めるKamal入門")
      end
    end

    context "when feed fetch fails" do
      before do
        stub_request(:get, feed_url).to_timeout
      end

      it "returns empty array when no cache exists" do
        articles = described_class.all

        expect(articles).to eq([])
      end

      it "returns stale cache when available" do
        # First, populate the cache with a successful request
        WebMock.reset!
        stub_request(:get, feed_url)
          .to_return(status: 200, body: sample_rss, headers: { "Content-Type" => "application/rss+xml" })
        described_class.all

        # Clear the main cache but keep stale cache
        Rails.cache.delete(ZennArticle::CACHE_KEY)

        # Then, simulate failure
        WebMock.reset!
        stub_request(:get, feed_url).to_timeout

        articles = described_class.all

        expect(articles).to be_an(Array)
        expect(articles.size).to eq(3)
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:warn).with(/Failed to fetch Zenn feed/)

        described_class.all
      end
    end

    context "when feed returns HTTP error" do
      before do
        stub_request(:get, feed_url).to_return(status: 500, body: "Internal Server Error")
      end

      it "returns empty array when no cache exists" do
        articles = described_class.all

        expect(articles).to eq([])
      end
    end

    context "when feed XML is invalid" do
      before do
        stub_request(:get, feed_url)
          .to_return(status: 200, body: "invalid xml", headers: { "Content-Type" => "application/rss+xml" })
      end

      it "returns empty array when no cache exists" do
        articles = described_class.all

        expect(articles).to eq([])
      end
    end
  end

  describe "instance" do
    subject(:article) do
      described_class.new(
        title: "Test Article",
        description: "Test description",
        url: "https://zenn.dev/test/articles/test",
        published_at: Time.zone.parse("2024-12-09 10:00:00")
      )
    end

    it "has title" do
      expect(article.title).to eq("Test Article")
    end

    it "has description" do
      expect(article.description).to eq("Test description")
    end

    it "has url" do
      expect(article.url).to eq("https://zenn.dev/test/articles/test")
    end

    it "has published_at" do
      expect(article.published_at).to eq(Time.zone.parse("2024-12-09 10:00:00"))
    end
  end
end
