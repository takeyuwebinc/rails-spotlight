require 'rails_helper'

RSpec.describe "Slides", type: :request do
  describe "GET /slides/:id" do
    let(:slide) { create(:slide, :with_pages) }
    let(:draft_slide) { create(:slide, :draft, :with_pages) }

    context "with published slide" do
      it "returns http success" do
        get slide_path(slide)
        expect(response).to have_http_status(:success)
      end

      it "displays the slide title" do
        get slide_path(slide)
        expect(response.body).to include(slide.title)
      end

      it "displays the first page content by default" do
        get slide_path(slide)
        first_page = slide.slide_pages.first
        expect(response.body).to include(first_page.content)
      end

      it "displays page navigation" do
        get slide_path(slide)
        expect(response.body).to include("1 / #{slide.page_count}")
      end
    end

    context "with specific page parameter" do
      it "displays the requested page" do
        second_page = slide.slide_pages.find_by(position: 2)
        get slide_path(slide, page: 2)
        expect(response.body).to include(second_page.content)
      end

      it "redirects to first page for invalid page number" do
        get slide_path(slide, page: 999)
        expect(response).to redirect_to(slide_path(slide, page: 1))
      end

      it "redirects to first page for zero page number" do
        get slide_path(slide, page: 0)
        expect(response).to redirect_to(slide_path(slide, page: 1))
      end
    end

    context "with draft slide" do
      context "in local environment" do
        before do
          allow(Rails.env).to receive(:local?).and_return(true)
        end

        it "allows access to draft slides" do
          get slide_path(draft_slide)
          expect(response).to have_http_status(:success)
        end
      end

      context "in non-local environment" do
        before do
          allow(Rails.env).to receive(:local?).and_return(false)
        end

        it "returns 404 for draft slides" do
          get slide_path(draft_slide)
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context "navigation links" do
      it "shows next link on first page" do
        get slide_path(slide, page: 1)
        expect(response.body).to include(slide_path(slide, page: 2))
        expect(response.body).to include("次へ")
      end

      it "shows previous link on middle pages" do
        get slide_path(slide, page: 2)
        expect(response.body).to include(slide_path(slide, page: 1))
        expect(response.body).to include("前へ")
      end

      it "does not show next link on last page" do
        last_page = slide.page_count
        get slide_path(slide, page: last_page)
        expect(response.body).not_to include(slide_path(slide, page: last_page + 1))
      end

      it "does not show previous link on first page" do
        get slide_path(slide, page: 1)
        expect(response.body).not_to include(slide_path(slide, page: 0))
      end
    end

    context "with non-existent slide" do
      it "returns 404" do
        get slide_path("non-existent-slug")
        expect(response).to have_http_status(:not_found)
      end
    end

    context "slide viewer attributes" do
      it "includes data attributes for Stimulus controller" do
        get slide_path(slide)
        expect(response.body).to include('data-controller="slide-viewer"')
        expect(response.body).to include("data-slide-viewer-total-value=\"#{slide.page_count}\"")
        expect(response.body).to include('data-slide-viewer-current-value="1"')
      end
    end
  end
end
