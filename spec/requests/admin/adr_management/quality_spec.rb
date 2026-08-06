# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin AdrManagement Quality", type: :request do
  describe "authentication" do
    it "redirects to login when not signed in" do
      get "/admin/adr/quality"
      expect(response).to redirect_to("/admin/login")
    end
  end

  describe "GET /admin/adr/quality" do
    before { sign_in_admin }

    it "shows the summary and the pending finding queue with actions" do
      adr = create(:adr_management_adr, title: "品質対象の決定")
      create(:adr_management_quality_assessment, adr: adr, findings: [
        { "code" => "alternatives_missing", "field" => "alternatives", "message" => "代替案が記録されていません" }
      ])

      get "/admin/adr/quality"

      expect(response).to have_http_status(:success)
      expect(response.body).to include("品質所見", adr.display_number, "品質対象の決定")
      expect(response.body).to include("代替案が記録されていません", "修正した", "誤検知として却下")
    end

    it "hides reviewed assessments from the queue" do
      assessment = create(:adr_management_quality_assessment, reviewed_at: Time.current, findings: [
        { "code" => "alternatives_missing", "field" => "alternatives",
          "message" => "処理済みの所見", "review_result" => "dismissed" }
      ])

      get "/admin/adr/quality"

      expect(response.body).not_to include("処理済みの所見")
      expect(assessment.adr).to be_present
    end
  end

  describe "POST /admin/adr/quality_assessments/:id/finding_review" do
    before { sign_in_admin }

    let(:assessment) do
      create(:adr_management_quality_assessment, findings: [
        { "code" => "alternatives_missing", "field" => "alternatives", "message" => "m1" },
        { "code" => "status_quo_missing", "field" => "alternatives", "message" => "m2" }
      ])
    end

    it "resolves a single finding and keeps the assessment pending" do
      post "/admin/adr/quality_assessments/#{assessment.id}/finding_review",
        params: { code: "alternatives_missing", review_result: "addressed" }

      expect(response).to redirect_to("/admin/adr/quality")
      assessment.reload
      results = assessment.findings.to_h { |f| [ f["code"], f["review_result"] ] }
      expect(results).to eq("alternatives_missing" => "addressed", "status_quo_missing" => nil)
      expect(assessment.reviewed_at).to be_nil
    end

    it "marks the assessment reviewed once the last finding is processed" do
      post "/admin/adr/quality_assessments/#{assessment.id}/finding_review",
        params: { code: "alternatives_missing", review_result: "addressed" }
      post "/admin/adr/quality_assessments/#{assessment.id}/finding_review",
        params: { code: "status_quo_missing", review_result: "dismissed" }

      expect(assessment.reload.reviewed_at).to be_present
    end

    it "rejects results other than addressed and dismissed" do
      post "/admin/adr/quality_assessments/#{assessment.id}/finding_review",
        params: { code: "alternatives_missing", review_result: "obsolete" }

      expect(flash[:alert]).to be_present
      expect(assessment.reload.open_findings.size).to eq(2)
    end
  end
end
