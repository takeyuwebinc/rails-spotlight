require 'rails_helper'

RSpec.describe "Tags", type: :request do
  describe "GET /tags/:slug/articles" do
    let!(:rails_tag) { create(:tag, :rails) }
    let!(:kamal_tag) { create(:tag, :kamal) }
    let!(:rails_article) { create(:article, :with_rails_tag) }
    let!(:kamal_article) { create(:article, :with_kamal_tag) }
    let!(:unpublished_article) { create(:article, :unpublished, :with_rails_tag) }

    context "when tag exists" do
      before { get tag_articles_path(rails_tag.slug) }

      it "returns http success" do
        expect(response).to have_http_status(:success)
      end

      it "includes the tag name in the response" do
        expect(response.body).to include("Exploring Rails")
      end

      it "includes article count in the response" do
        expect(response.body).to include("1 article")
      end

      it "displays only published articles with the tag" do
        expect(response.body).to include(rails_article.title)
        expect(response.body).not_to include(kamal_article.title)
        expect(response.body).not_to include(unpublished_article.title)
      end

      it "includes structured data" do
        expect(response.body).to include("application/ld+json")
        expect(response.body).to include("CollectionPage")
        expect(response.body).to include("ItemList")
      end
    end

    context "when tag has multiple articles" do
      let!(:another_rails_article) { create(:article, :with_rails_tag, title: "Another Rails Article", slug: "another-rails-article") }

      before { get tag_articles_path(rails_tag.slug) }

      it "includes all published articles with the tag" do
        expect(response.body).to include(rails_article.title)
        expect(response.body).to include(another_rails_article.title)
      end

      it "shows correct article count" do
        expect(response.body).to include("2 articles")
      end
    end

    context "when tag has no articles" do
      let!(:empty_tag) { create(:tag, name: "EmptyTag", slug: "empty-tag") }

      before { get tag_articles_path(empty_tag.slug) }

      it "returns http success" do
        expect(response).to have_http_status(:success)
      end

      it "shows no articles message" do
        expect(response.body).to include("No articles found for this tag yet")
      end

      it "shows correct article count" do
        expect(response.body).to include("0 articles")
      end
    end

    context "when tag does not exist" do
      it "redirects to articles index" do
        get tag_articles_path("non-existent-tag")
        expect(response).to redirect_to(articles_path)
      end

      it "sets flash alert message" do
        get tag_articles_path("non-existent-tag")
        expect(flash[:alert]).to eq("タグが見つかりませんでした")
      end
    end

    context "SEO and meta tags" do
      before { get tag_articles_path(rails_tag.slug) }

      it "sets correct page title" do
        expect(response.body).to include('<title>Rails Articles | TakeyuWeb</title>')
      end

      it "sets correct meta description" do
        expect(response.body).to include('name="description"')
        expect(response.body).to include("Articles and insights about Rails")
      end

      it "sets correct canonical URL" do
        expect(response.body).to include('rel="canonical"')
        expect(response.body).to include("/tags/rails/articles")
      end

      it "sets correct og:type" do
        expect(response.body).to include('property="og:type" content="website"')
      end
    end

    context "structured data" do
      before { get tag_articles_path(rails_tag.slug) }

      it "includes CollectionPage structured data" do
        expect(response.body).to include('"@type": "CollectionPage"')
      end

      it "includes ItemList with correct numberOfItems" do
        expect(response.body).to include('"@type": "ItemList"')
        expect(response.body).to include('"numberOfItems": 1')
      end

      it "includes author information" do
        expect(response.body).to include('"name": "Yuichi Takeuchi"')
      end

      it "includes publisher information" do
        expect(response.body).to include('"name": "TakeyuWeb Inc."')
      end
    end
  end
end
