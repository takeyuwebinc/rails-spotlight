require 'rails_helper'

RSpec.describe "Home", type: :request do
  describe "GET /" do
    context "basic functionality" do
      before { get root_path }

      it "returns http success" do
        expect(response).to have_http_status(:success)
      end

      it "displays zenn articles turbo frame" do
        expect(response.body).to include('id="zenn_articles"')
        expect(response.body).to include('src="/zenn_articles"')
        expect(response.body).to include('turbo-frame')
      end

      it "displays skeleton loading placeholder" do
        expect(response.body).to include("animate-pulse")
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
        # Checking for any high capacity percentage (95% or 100%)
        expect(response.body).to include("100%")
        expect(response.body).to include("95%")
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
