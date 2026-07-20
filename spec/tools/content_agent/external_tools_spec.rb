require "rails_helper"

RSpec.describe ContentAgent::FetchUrlTool do
  describe "#execute" do
    it "ページ本文をテキスト化して返す" do
      stub_request(:get, "https://example.com/event")
        .to_return(status: 200, body: <<~HTML)
          <html><head><title>Fukuoka.rb #100</title><script>evil()</script></head>
          <body><h1>Fukuoka.rb #100</h1><p>2026年7月19日 開催</p></body></html>
        HTML

      result = described_class.new.execute(url: "https://example.com/event")

      expect(result[:title]).to eq("Fukuoka.rb #100")
      expect(result[:text]).to include("2026年7月19日 開催")
      expect(result[:text]).not_to include("evil()")
    end

    it "リダイレクトを追従する" do
      stub_request(:get, "https://example.com/old")
        .to_return(status: 301, headers: { "Location" => "https://example.com/new" })
      stub_request(:get, "https://example.com/new")
        .to_return(status: 200, body: "<html><title>moved</title><body>ok</body></html>")

      result = described_class.new.execute(url: "https://example.com/old")

      expect(result[:title]).to eq("moved")
    end

    it "HTTP エラーはエラーとして返す" do
      stub_request(:get, "https://example.com/broken").to_return(status: 500)

      result = described_class.new.execute(url: "https://example.com/broken")

      expect(result[:error]).to include("500")
    end

    it "http/https 以外はエラーを返す" do
      result = described_class.new.execute(url: "file:///etc/passwd")

      expect(result[:error]).to be_present
    end
  end
end

RSpec.describe ContentAgent::WebSearchTool do
  describe "#execute" do
    it "Brave Search の結果を整形して返す" do
      stub_request(:get, %r{https://api\.search\.brave\.com/res/v1/web/search})
        .with(headers: { "X-Subscription-Token" => /.+/ })
        .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: {
          web: { results: [
            { title: "Fukuoka.rb", url: "https://fukuokarb.example", description: "Ruby community" }
          ] }
        }.to_json)

      result = described_class.new.execute(query: "Fukuoka.rb")

      expect(result[:results]).to eq([
        { title: "Fukuoka.rb", url: "https://fukuokarb.example", description: "Ruby community" }
      ])
    end

    it "API エラーはエラーとして返す" do
      stub_request(:get, %r{https://api\.search\.brave\.com/}).to_return(status: 429)

      result = described_class.new.execute(query: "q")

      expect(result[:error]).to include("429")
    end
  end
end
