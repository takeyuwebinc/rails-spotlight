require 'rails_helper'

RSpec.describe "Articles", type: :request do
  describe "GET /articles" do
    let!(:article1) { create(:article, title: "First Article", slug: "first-article") }
    let!(:article2) { create(:article, title: "Second Article", slug: "second-article") }
    let!(:unpublished_article) { create(:article, :unpublished) }

    before { get articles_path }

    it "returns http success" do
      expect(response).to have_http_status(:success)
    end

    it "displays only published articles" do
      expect(response.body).to include("First Article")
      expect(response.body).to include("Second Article")
      expect(response.body).not_to include(unpublished_article.title)
    end
  end

  describe "GET /articles/:slug" do
    context "with published article" do
      let!(:rails_tag) { create(:tag, :rails) }
      let!(:kamal_tag) { create(:tag, :kamal) }
      let!(:article) { create(:article, :with_rails_tag, title: "Test Article", slug: "test-article") }

      before do
        article.tags << kamal_tag
        get article_path(article)
      end

      it "returns http success" do
        expect(response).to have_http_status(:success)
      end

      it "displays the article title" do
        expect(response.body).to include("Test Article")
      end

      it "displays tag badges" do
        expect(response.body).to include("Rails")
        expect(response.body).to include("Kamal")
      end

      it "includes tag links to tag articles pages" do
        expect(response.body).to include(tag_articles_path(rails_tag.slug))
        expect(response.body).to include(tag_articles_path(kamal_tag.slug))
      end

      it "displays tag badges with correct colors" do
        expect(response.body).to include("bg-red-600") # Rails background color
        expect(response.body).to include("text-red-100") # Rails text color
        expect(response.body).to include("bg-blue-600") # Kamal background color
        expect(response.body).to include("text-blue-100") # Kamal text color
      end

      it "includes SEO meta tags" do
        expect(response.body).to include('<title>Test Article | TakeyuWeb</title>')
        expect(response.body).to include('name="description"')
        expect(response.body).to include('rel="canonical"')
      end

      it "includes structured data" do
        expect(response.body).to include("application/ld+json")
        expect(response.body).to include("TechArticle")
      end
    end

    context "with article without tags" do
      let!(:article) { create(:article, title: "No Tags Article", slug: "no-tags-article") }

      before { get article_path(article) }

      it "returns http success" do
        expect(response).to have_http_status(:success)
      end

      it "does not display tag badges section" do
        expect(response.body).not_to include("flex flex-wrap gap-2 md:mb-6")
      end
    end

    context "with unpublished article" do
      let!(:unpublished_article) { create(:article, :unpublished) }

      it "returns http success for unpublished articles" do
        # Note: The current implementation doesn't check publication status in show action
        get article_path(unpublished_article)
        expect(response).to have_http_status(:success)
      end
    end

    context "with non-existent article" do
      it "returns http not found error for non-existent" do
        get article_path("non-existent-slug")
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "tag functionality in articles" do
    let!(:rails_tag) { create(:tag, :rails) }
    let!(:javascript_tag) { create(:tag, :javascript) }
    let!(:article_with_multiple_tags) do
      create(:article, title: "Multi Tag Article", slug: "multi-tag-article").tap do |article|
        article.tags << [ rails_tag, javascript_tag ]
      end
    end

    before { get article_path(article_with_multiple_tags) }

    it "displays all tags for an article" do
      expect(response.body).to include("Rails")
      expect(response.body).to include("JavaScript")
    end

    it "includes links to all tag pages" do
      expect(response.body).to include(tag_articles_path(rails_tag.slug))
      expect(response.body).to include(tag_articles_path(javascript_tag.slug))
    end

    it "displays correct colors for each tag" do
      expect(response.body).to include("bg-red-600") # Rails background
      expect(response.body).to include("bg-yellow-500") # JavaScript background
    end
  end
end
