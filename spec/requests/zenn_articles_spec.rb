require "rails_helper"

RSpec.describe "ZennArticles" do
  let(:feed_url) { ZennArticle::FEED_URL }
  let(:sample_rss) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
        <channel>
          <title>タケユー・ウェブ株式会社のフィード</title>
          <link>https://zenn.dev/p/takeyuwebinc</link>
          <item>
            <title>Rails 8で始めるKamal入門</title>
            <link>https://zenn.dev/takeyuwebinc/articles/rails8-kamal-intro</link>
            <description>Rails 8から標準になったKamalについて解説します。</description>
            <pubDate>Mon, 09 Dec 2024 10:00:00 +0900</pubDate>
            <guid>https://zenn.dev/takeyuwebinc/articles/rails8-kamal-intro</guid>
          </item>
          <item>
            <title>Claude Codeを使った開発効率化</title>
            <link>https://zenn.dev/takeyuwebinc/articles/claude-code-dev</link>
            <description>Claude Codeを使った開発ワークフローを紹介します。</description>
            <pubDate>Sun, 08 Dec 2024 09:00:00 +0900</pubDate>
            <guid>https://zenn.dev/takeyuwebinc/articles/claude-code-dev</guid>
          </item>
          <item>
            <title>TailwindCSSでのダークモード実装</title>
            <link>https://zenn.dev/takeyuwebinc/articles/tailwind-dark-mode</link>
            <description>TailwindCSSでダークモードを実装する方法。</description>
            <pubDate>Sat, 07 Dec 2024 08:00:00 +0900</pubDate>
            <guid>https://zenn.dev/takeyuwebinc/articles/tailwind-dark-mode</guid>
          </item>
        </channel>
      </rss>
    XML
  end

  around do |example|
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
    Rails.cache = original_cache
  end

  describe "GET /zenn_articles" do
    context "when feed is available" do
      before do
        stub_request(:get, feed_url)
          .to_return(status: 200, body: sample_rss, headers: { "Content-Type" => "application/rss+xml" })
      end

      it "returns success" do
        get zenn_articles_path

        expect(response).to have_http_status(:success)
      end

      it "renders turbo frame with articles" do
        get zenn_articles_path

        expect(response.body).to include("turbo-frame")
        expect(response.body).to include("zenn_articles")
        expect(response.body).to include("Rails 8で始めるKamal入門")
      end

      it "displays articles as external links" do
        get zenn_articles_path

        expect(response.body).to include('target="_blank"')
        expect(response.body).to include('rel="noopener noreferrer"')
      end

      it "limits to 3 articles" do
        get zenn_articles_path

        expect(response.body).to include("Rails 8で始めるKamal入門")
        expect(response.body).to include("Claude Codeを使った開発効率化")
        expect(response.body).to include("TailwindCSSでのダークモード実装")
      end
    end

    context "when feed is unavailable" do
      before do
        stub_request(:get, feed_url).to_timeout
      end

      it "returns success with empty content" do
        get zenn_articles_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include("turbo-frame")
        expect(response.body).to include("zenn_articles")
      end
    end
  end
end
