# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin AdrManagement SearchQuality", type: :request do
  describe "authentication" do
    it "redirects to login when not signed in" do
      get "/admin/adr/search_quality"
      expect(response).to redirect_to("/admin/login")
    end
  end

  describe "GET /admin/adr/search_quality" do
    before { sign_in_admin }

    it "shows the summary, review queues, evaluations and golden queries" do
      create(:adr_management_search_log, mode: "keyword", query: nil, keyword: "ペイロード", result_count: 0)
      adr = create(:adr_management_adr, title: "到達した決定")
      create(:adr_management_search_miss_report, adr: adr, query: "失敗したクエリ")
      create(:adr_management_search_evaluation, recall: 0.875)
      create(:adr_management_golden_query, query: "登録済みクエリ", adr: adr)

      get "/admin/adr/search_quality"

      expect(response).to have_http_status(:success)
      expect(response.body).to include("検索品質")
      expect(response.body).to include("ペイロード", "取り逃がしとして記録", "問題なし")
      expect(response.body).to include("失敗したクエリ", "ゴールデンクエリとして採用", "対応済みにする")
      expect(response.body).to include("0.875")
      expect(response.body).to include("登録済みクエリ")
    end
  end

  describe "POST /admin/adr/search_logs/:id/miss_report" do
    before { sign_in_admin }

    it "records a miss report with the reached ADR and marks the log reviewed" do
      log = create(:adr_management_search_log, mode: "keyword", query: nil, keyword: "ペイロード", result_count: 0)
      engagement = create(:adr_management_engagement, code: "fabble")
      adr = create(:adr_management_adr, engagement: engagement)

      expect {
        post "/admin/adr/search_logs/#{log.id}/miss_report", params: {
          note: "payload で到達", engagement_code: "FABBLE", number: adr.number
        }
      }.to change(AdrManagement::SearchMissReport, :count).by(1)

      expect(response).to redirect_to("/admin/adr/search_quality")
      expect(flash[:notice]).to eq("取り逃がしとして記録しました。")
      report = AdrManagement::SearchMissReport.last
      expect(report.query).to eq("ペイロード")
      expect(report.adr).to eq(adr)
      expect(report.origin).to start_with("admin:")
      expect(log.reload.reviewed_at).to be_present
    end

    it "rejects a partial ADR reference without recording" do
      log = create(:adr_management_search_log, result_count: 0)

      expect {
        post "/admin/adr/search_logs/#{log.id}/miss_report", params: { note: "n", engagement_code: "fabble" }
      }.not_to change(AdrManagement::SearchMissReport, :count)

      expect(flash[:alert]).to include("両方")
      expect(log.reload.reviewed_at).to be_nil
    end

    it "keeps the log pending when the report is invalid" do
      log = create(:adr_management_search_log, result_count: 0)

      post "/admin/adr/search_logs/#{log.id}/miss_report", params: { note: "" }

      expect(flash[:alert]).to be_present
      expect(log.reload.reviewed_at).to be_nil
    end
  end

  describe "POST /admin/adr/search_logs/:id/review" do
    before { sign_in_admin }

    it "marks the log reviewed" do
      log = create(:adr_management_search_log, result_count: 0)

      post "/admin/adr/search_logs/#{log.id}/review"

      expect(flash[:notice]).to eq("0件検索を問題なしとして処理しました。")
      expect(log.reload.reviewed_at).to be_present
    end
  end

  describe "POST /admin/adr/search_miss_reports/:id/golden_query" do
    before { sign_in_admin }

    it "adopts the report as a golden query with an edited query text" do
      adr = create(:adr_management_adr)
      report = create(:adr_management_search_miss_report, adr: adr, query: "ペイロード")

      expect {
        post "/admin/adr/search_miss_reports/#{report.id}/golden_query", params: {
          query: "ペイロードの検証について決めたことは？"
        }
      }.to change(AdrManagement::GoldenQuery, :count).by(1)

      golden_query = AdrManagement::GoldenQuery.last
      expect(golden_query.query).to eq("ペイロードの検証について決めたことは？")
      expect(golden_query.adr).to eq(adr)
      expect(report.reload.reviewed_at).to be_present
    end

    it "rejects adoption when the report has no reached ADR" do
      report = create(:adr_management_search_miss_report, adr: nil)

      expect {
        post "/admin/adr/search_miss_reports/#{report.id}/golden_query"
      }.not_to change(AdrManagement::GoldenQuery, :count)

      expect(flash[:alert]).to include("採用できません")
      expect(report.reload.reviewed_at).to be_nil
    end
  end

  describe "POST /admin/adr/search_miss_reports/:id/review" do
    before { sign_in_admin }

    it "marks the report reviewed" do
      report = create(:adr_management_search_miss_report)

      post "/admin/adr/search_miss_reports/#{report.id}/review"

      expect(flash[:notice]).to eq("取り逃がし報告を対応済みにしました。")
      expect(report.reload.reviewed_at).to be_present
    end
  end
end
