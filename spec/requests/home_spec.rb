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

      it "displays availability percentage" do
        # With no estimates, shows 0% (green color)
        expect(response.body).to include("0%")
      end

      it "displays progress bars" do
        expect(response.body).to match(/style="width: \d+%"/)
      end

      it "uses appropriate color for capacity" do
        # With no estimates (0%), uses green color
        expect(response.body).to include("bg-green-500")
        expect(response.body).to include("text-green-600")
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

    context "availability status section with estimates" do
      let(:project) { create(:work_hour_project, status: "active") }

      before do
        3.times do |i|
          create(:work_hour_project_monthly_estimate,
                 project: project,
                 year_month: Date.current.next_month(i).beginning_of_month,
                 estimated_hours: 160)
        end
        get root_path
      end

      it "displays 100% for fully booked months" do
        expect(response.body).to include("100%")
      end

      it "uses red color for full capacity" do
        expect(response.body).to include("bg-red-500")
        expect(response.body).to include("text-red-600")
      end
    end
  end
end
