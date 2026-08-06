# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::AdrManagement::Adrs", type: :request do
  before { sign_in_admin }

  let!(:engagement) { create(:adr_management_engagement, code: "fabble", name: "Fabble") }

  describe "GET /admin/adr/adrs" do
    it "filters by engagement, status, and keyword" do
      other = create(:adr_management_engagement, code: "other")
      create(:adr_management_adr, engagement: engagement, title: "認証方式の選定", status: "accepted")
      create(:adr_management_adr, engagement: engagement, title: "提案中の決定", status: "proposed")
      create(:adr_management_adr, engagement: other, title: "他案件の決定", status: "accepted")

      get admin_adr_management_adrs_path,
        params: { engagement_id: engagement.id, status: "accepted", keyword: "認証" }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("認証方式の選定")
      expect(response.body).not_to include("提案中の決定")
      expect(response.body).not_to include("他案件の決定")
    end

    it "matches the keyword against generated search aliases" do
      create(:adr_management_adr, engagement: engagement, title: "payload 検証方式の選定",
        search_aliases: "ペイロード")

      get admin_adr_management_adrs_path, params: { keyword: "ペイロード" }

      expect(response.body).to include("payload 検証方式の選定")
    end
  end

  describe "GET /admin/adr/adrs/:id" do
    it "renders the body as markdown and shows revisions" do
      adr = create(:adr_management_adr, engagement: engagement,
        context: "**強調された制約**", decision: "決定本文")
      adr.record_revision!(change_type: "created", origin: "oauth:Agent")

      get admin_adr_management_adr_path(adr)

      expect(response.body).to include("<strong>強調された制約</strong>")
      expect(response.body).to include("oauth:Agent")
    end

    it "shows the generated search aliases" do
      adr = create(:adr_management_adr, engagement: engagement, search_aliases: "ペイロード\nスキーマ")

      get admin_adr_management_adr_path(adr)

      expect(response.body).to include("検索エイリアス", "ペイロード", "スキーマ")
    end

    it "uses the ADR number in the URL instead of the database id" do
      adr = create(:adr_management_adr, engagement: engagement)

      expect(admin_adr_management_adr_path(adr)).to eq("/admin/adr/adrs/FABBLE-#{adr.number}")

      get admin_adr_management_adr_path(adr)
      expect(response).to have_http_status(:success)
    end

    it "keeps resolving legacy id-based URLs" do
      adr = create(:adr_management_adr, engagement: engagement)

      get "/admin/adr/adrs/#{adr.id}"
      expect(response).to have_http_status(:success)
    end

    it "shows the latest quality assessment of each layer with the finding state" do
      adr = create(:adr_management_adr, engagement: engagement)
      create(:adr_management_quality_assessment, adr: adr, layer: "rule",
        content_fingerprint: "a" * 64, origin: "admin:old@example.com",
        reviewed_at: Time.current, created_at: 2.days.ago, findings: [
          { "code" => "alternatives_missing", "field" => "alternatives",
            "message" => "旧版の所見", "review_result" => "addressed" }
        ])
      create(:adr_management_quality_assessment, adr: adr, layer: "rule",
        origin: "admin:new@example.com", created_at: 1.day.ago, findings: [
          { "code" => "status_quo_missing", "field" => "alternatives",
            "message" => "現状維持案の検討が見当たりません" }
        ])

      get admin_adr_management_adr_path(adr)

      expect(response.body).to include("品質所見", "現状維持案の検討が見当たりません", "未処理")
      expect(response.body).to include("admin:new@example.com")
      # 層ごとに最新の1件のみを表示する
      expect(response.body).not_to include("旧版の所見")
      # 評価が無い層は未評価として示す
      expect(response.body).to include("LLM", "未評価")
    end

    it "shows an assessed ADR without findings as having none" do
      adr = create(:adr_management_adr, engagement: engagement)
      create(:adr_management_quality_assessment, adr: adr, layer: "rule",
        findings: [], reviewed_at: Time.current)

      get admin_adr_management_adr_path(adr)

      expect(response.body).to include("所見なし")
    end

    it "shows the supersession chain" do
      old_adr = create(:adr_management_adr, engagement: engagement, status: "accepted", title: "旧決定")
      result = AdrManagement::RegisterAdr.perform(
        engagement: engagement,
        attributes: { title: "新決定", confidence: "high", decided_on: Date.current,
                      context: "c", decision: "d", consequences: "q" },
        origin: "test", superseded_numbers: [ old_adr.number ]
      )

      get admin_adr_management_adr_path(result.data)
      expect(response.body).to include("置換変遷", "旧決定")

      get admin_adr_management_adr_path(old_adr)
      expect(response.body).to include("置き換えられています", "新決定")
    end
  end

  describe "POST /admin/adr/adrs" do
    let(:base_params) do
      {
        engagement_id: engagement.id,
        title: "認証方式の選定",
        status: "accepted",
        confidence: "high",
        decided_on: "2026-07-01",
        context: "コンテキスト",
        decision: "決定",
        consequences: "結果"
      }
    end

    it "registers an adr with the admin email as origin" do
      expect {
        post admin_adr_management_adrs_path, params: { adr_management_adr: base_params }
      }.to change(engagement.adrs, :count).by(1)

      adr = engagement.adrs.sole
      expect(adr.number).to eq(1)
      expect(adr.revisions.sole.origin).to eq("admin:test@takeyuweb.co.jp")
    end

    it "registers with supersession via checkboxes" do
      old_adr = create(:adr_management_adr, engagement: engagement, status: "accepted")

      post admin_adr_management_adrs_path,
        params: { adr_management_adr: base_params, superseded_numbers: [ old_adr.number ] }

      expect(old_adr.reload.status).to eq("superseded")
      new_adr = engagement.adrs.order(:number).last
      expect(new_adr.superseded_adrs).to contain_exactly(old_adr)
    end

    it "re-renders the form with structured errors on failure" do
      post admin_adr_management_adrs_path,
        params: { adr_management_adr: base_params.merge(title: "") }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Title")
    end
  end

  describe "PATCH /admin/adr/adrs/:id" do
    it "updates content and allowed status transitions" do
      adr = create(:adr_management_adr, engagement: engagement, status: "proposed")

      patch admin_adr_management_adr_path(adr),
        params: { adr_management_adr: { title: "更新後タイトル", status: "accepted" } }

      expect(response).to redirect_to(admin_adr_management_adr_path(adr))
      expect(adr.reload.title).to eq("更新後タイトル")
      expect(adr.status).to eq("accepted")
    end

    it "shows an error for a forbidden status transition" do
      adr = create(:adr_management_adr, engagement: engagement, status: "accepted")

      patch admin_adr_management_adr_path(adr),
        params: { adr_management_adr: { status: "rejected" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(adr.reload.status).to eq("accepted")
    end

    it "moves the adr to another engagement with renumbering" do
      target = create(:adr_management_engagement, code: "target")
      create(:adr_management_adr, engagement: target)
      adr = create(:adr_management_adr, engagement: engagement)

      patch admin_adr_management_adr_path(adr),
        params: { adr_management_adr: { engagement_id: target.id } }

      adr.reload
      expect(adr.engagement).to eq(target)
      expect(adr.number).to eq(2)
      expect(adr.revisions.where(change_type: "engagement_changed")).to be_present
    end
  end

  describe "DELETE /admin/adr/adrs/:id" do
    it "deletes an adr together with its revisions" do
      adr = create(:adr_management_adr, engagement: engagement)
      adr.record_revision!(change_type: "created", origin: "test")

      expect {
        delete admin_adr_management_adr_path(adr)
      }.to change(AdrManagement::Adr, :count).by(-1)
        .and change(AdrManagement::AdrRevision, :count).by(-1)
    end

    it "refuses to delete an adr with supersession relations" do
      old_adr = create(:adr_management_adr, engagement: engagement, status: "accepted")
      result = AdrManagement::RegisterAdr.perform(
        engagement: engagement,
        attributes: { title: "新決定", confidence: "high", decided_on: Date.current,
                      context: "c", decision: "d", consequences: "q" },
        origin: "test", superseded_numbers: [ old_adr.number ]
      )

      expect {
        delete admin_adr_management_adr_path(result.data)
      }.not_to change(AdrManagement::Adr, :count)

      expect(flash[:alert]).to include("置換関係")
    end
  end
end
