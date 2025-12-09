require 'rails_helper'

RSpec.describe "LlmsTxt", type: :request do
  describe "GET /llms.txt" do
    before do
      # Projectのテストデータ
      2.times do |i|
        Project.create!(
          title: "Project #{i + 1}",
          description: "Test project description",
          icon: "icon-project",
          color: "blue",
          technologies: "Rails, Ruby",
          position: i,
          published_at: 1.day.ago
        )
      end

      # Speakingのテストデータ（SpeakingEngagementモデル）
      SpeakingEngagement.create!(
        title: "Test Speaking",
        slug: "test-speaking",
        event_name: "Test Conference",
        event_date: 1.month.ago,
        description: "Test speaking engagement",
        published: true
      )

      # UsesItemのテストデータ
      4.times do |i|
        UsesItem.create!(
          name: "Tool #{i + 1}",
          slug: "tool-#{i + 1}",
          description: "Test tool description",
          category: "development",
          published: true
        )
      end
    end

    it "returns successful response" do
      get "/llms.txt"
      expect(response).to have_http_status(200)
    end

    it "returns text/plain content type" do
      get "/llms.txt"
      expect(response.content_type).to match(/text\/plain/)
    end

    it "includes site title" do
      get "/llms.txt"
      expect(response.body).to include("# Spotlight by タケユー・ウェブ株式会社")
    end

    it "includes correct project count" do
      get "/llms.txt"
      expect(response.body).to include("公開実績数: 2件")
    end

    it "includes correct speaking count" do
      get "/llms.txt"
      expect(response.body).to include("カンファレンス登壇実績（1件）")
    end

    it "includes correct uses count" do
      get "/llms.txt"
      expect(response.body).to include("使用ツール・開発環境の紹介（4件）")
    end

    it "includes availability information" do
      get "/llms.txt"
      expect(response.body).to include("現在の稼働率:")
      expect(response.body).to include("次回受付可能時期:")
      expect(response.body).to include("ステータス:")
    end

    it "includes generation timestamp" do
      get "/llms.txt"
      expect(response.body).to match(/Generated at: \d{4}-\d{2}-\d{2}/)
    end

    it "sets appropriate cache headers" do
      get "/llms.txt"
      expect(response.headers["Cache-Control"]).to include("public")
      expect(response.headers["Cache-Control"]).to include("max-age=3600")
    end

    it "sets ETag header" do
      get "/llms.txt"
      expect(response.headers["ETag"]).to be_present
    end

    it "sets Last-Modified header" do
      get "/llms.txt"
      expect(response.headers["Last-Modified"]).to be_present
    end

    it "responds with 304 Not Modified for conditional requests" do
      get "/llms.txt"
      etag = response.headers["ETag"]

      get "/llms.txt", headers: { "If-None-Match" => etag }
      expect(response).to have_http_status(304)
    end
  end
end
