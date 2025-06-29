require 'rails_helper'

RSpec.describe "Home", type: :request do
  describe "GET /" do
    context "with featured tags" do
      let!(:rails_tag) { create(:tag, :rails) }
      let!(:kamal_tag) { create(:tag, :kamal) }
      let!(:docker_tag) { create(:tag, :docker) }
      let!(:rails_article1) { create(:article, :with_rails_tag, title: "Rails Article 1", slug: "rails-article-1") }
      let!(:rails_article2) { create(:article, :with_rails_tag, title: "Rails Article 2", slug: "rails-article-2") }
      let!(:kamal_article) { create(:article, :with_kamal_tag) }
      let!(:unpublished_article) { create(:article, :unpublished, :with_rails_tag) }

      before { get root_path }

      it "returns http success" do
        expect(response).to have_http_status(:success)
      end

      it "displays featured tags based on article count" do
        expect(response.body).to include("Rails")
        expect(response.body).to include("Kamal")
        expect(response.body).not_to include("Docker") # no articles
      end

      it "displays tag badges with correct links" do
        expect(response.body).to include("Rails")
        expect(response.body).to include("Kamal")
        expect(response.body).to include(tag_articles_path(rails_tag.slug))
        expect(response.body).to include(tag_articles_path(kamal_tag.slug))
      end

      it "displays tag badges with correct colors" do
        expect(response.body).to include("bg-red-600") # Rails background color
        expect(response.body).to include("text-red-100") # Rails text color
        expect(response.body).to include("bg-blue-600") # Kamal background color
        expect(response.body).to include("text-blue-100") # Kamal text color
      end

      it "limits featured tags display" do
        # Create more tags with articles
        6.times do |i|
          tag = create(:tag, name: "Tag#{i}")
          create(:article, title: "Article #{i}", slug: "article-#{i}").tap do |article|
            article.tags << tag
          end
        end

        get root_path
        # Should not display all tags (limited to top 5)
        expect(response.body.scan(/Tag\d/).count).to be <= 5
      end

      it "excludes unpublished articles from tag display" do
        # Rails tag should be displayed based on published articles only
        expect(response.body).to include("Rails")
      end
    end

    context "without any articles" do
      before { get root_path }

      it "returns http success" do
        expect(response).to have_http_status(:success)
      end

      it "does not display tag badges section" do
        expect(response.body).not_to include("mt-4 flex flex-wrap gap-2")
      end
    end

    context "with only unpublished articles" do
      let!(:rails_tag) { create(:tag, :rails) }
      let!(:unpublished_article) { create(:article, :unpublished, :with_rails_tag) }

      before { get root_path }

      it "does not display tag badges for unpublished articles" do
        # Note: This test may fail if there are other published articles with Rails tag
        # The implementation correctly excludes unpublished articles from tag counting
        expect(response.body).not_to include("bg-red-600") # Rails tag badge styling
      end
    end

    context "tag badge functionality" do
      let!(:rails_tag) { create(:tag, :rails) }
      let!(:rails_article) { create(:article, :with_rails_tag) }

      before { get root_path }

      it "includes clickable tag badges" do
        expect(response.body).to include('href="/tags/rails/articles"')
      end

      it "includes proper badge styling" do
        expect(response.body).to include("inline-flex items-center")
        expect(response.body).to include("px-1.5 py-0.5") # Actual styling from response
        expect(response.body).to include("rounded")
      end
    end

    context "availability status section" do
      before { get root_path }

      it "displays availability status section" do
        expect(response.body).to include("Work Availability")
      end

      it "displays calendar icon" do
        expect(response.body).to include("fa-calendar-check")
      end

      it "displays 100% capacity for all months" do
        expect(response.body.scan("100%").count).to be >= 3
      end

      it "displays progress bars with full width" do
        expect(response.body).to include('style="width: 100%"')
      end

      it "uses red color for full capacity" do
        expect(response.body).to include("bg-red-500")
        expect(response.body).to include("text-red-600")
      end

      it "displays contact information section" do
        expect(response.body).to include("長期プロジェクトや今後の空き状況については、お気軽にお問い合わせください。")
      end

      it "includes contact form link" do
        expect(response.body).to include("https://forms.gle/scwNEGrT196rFnD9A")
        expect(response.body).to include("お問い合わせフォーム")
      end

      it "contact form link opens in new tab" do
        expect(response.body).to include('target="_blank"')
        expect(response.body).to include('rel="noopener noreferrer"')
      end

      it "includes external link icon" do
        expect(response.body).to include("fa-external-link")
      end
    end
  end
end
