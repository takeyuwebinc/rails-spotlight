require 'rails_helper'

RSpec.describe "Sitemaps", type: :request do
  describe "GET /sitemap.xml" do
    let!(:article1) { create(:article, title: "Test Article 1", slug: "test-article-1", published_at: 1.day.ago) }
    let!(:article2) { create(:article, title: "Test Article 2", slug: "test-article-2", published_at: 2.days.ago) }

    before do
      get "/sitemap.xml"
    end

    it "returns success" do
      expect(response).to have_http_status(:success)
    end

    it "returns XML content type" do
      expect(response.content_type).to include("application/xml")
    end

    it "includes the sitemap XML structure" do
      expect(response.body).to include('<?xml version="1.0" encoding="UTF-8"?>')
      expect(response.body).to include('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
    end

    it "includes the root URL" do
      expect(response.body).to include("<loc>#{root_url}</loc>")
    end

    it "includes articles index URL" do
      expect(response.body).to include("<loc>#{articles_url}</loc>")
    end

    it "includes individual article URLs" do
      expect(response.body).to include("<loc>#{article_url(article1)}</loc>")
      expect(response.body).to include("<loc>#{article_url(article2)}</loc>")
    end

    it "includes static page URLs" do
      expect(response.body).to include("<loc>#{about_url}</loc>")
      expect(response.body).to include("<loc>#{projects_url}</loc>")
    end

    it "includes lastmod dates" do
      expect(response.body).to include("<lastmod>#{article1.updated_at.iso8601}</lastmod>")
      expect(response.body).to include("<lastmod>#{article2.updated_at.iso8601}</lastmod>")
    end

    it "includes priority and changefreq" do
      expect(response.body).to include("<priority>1.0</priority>")
      expect(response.body).to include("<changefreq>weekly</changefreq>")
      expect(response.body).to include("<changefreq>daily</changefreq>")
      expect(response.body).to include("<changefreq>monthly</changefreq>")
    end
  end
end
