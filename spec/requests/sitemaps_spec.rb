require 'rails_helper'

RSpec.describe "Sitemaps", type: :request do
  describe "GET /sitemap.xml" do
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

    it "includes static page URLs" do
      expect(response.body).to include("<loc>#{about_url}</loc>")
      expect(response.body).to include("<loc>#{projects_url}</loc>")
    end

    it "includes priority and changefreq" do
      expect(response.body).to include("<priority>1.0</priority>")
      expect(response.body).to include("<changefreq>weekly</changefreq>")
      expect(response.body).to include("<changefreq>monthly</changefreq>")
    end
  end
end
