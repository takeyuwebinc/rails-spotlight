# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::AdrManagement::Engagements", type: :request do
  before { sign_in_admin }

  describe "GET /admin/adr/engagements/:id" do
    it "shows projects and adrs of the engagement" do
      engagement = create(:adr_management_engagement, code: "fabble", name: "Fabble")
      create(:adr_management_project, engagement: engagement, name: "保守開発2026年度")
      create(:adr_management_adr, engagement: engagement, title: "認証方式の選定")

      get admin_adr_management_engagement_path(engagement)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Fabble", "保守開発2026年度", "認証方式の選定")
    end
  end

  describe "POST /admin/adr/engagements" do
    it "creates an engagement under a client" do
      client = create(:adr_management_client)

      expect {
        post admin_adr_management_engagements_path,
          params: { adr_management_engagement: { code: "fabble", name: "Fabble", client_id: client.id } }
      }.to change(AdrManagement::Engagement, :count).by(1)
    end
  end

  describe "DELETE /admin/adr/engagements/:id" do
    it "deletes an empty engagement" do
      engagement = create(:adr_management_engagement)

      expect {
        delete admin_adr_management_engagement_path(engagement)
      }.to change(AdrManagement::Engagement, :count).by(-1)
    end

    it "refuses to delete an engagement with adrs" do
      engagement = create(:adr_management_engagement)
      create(:adr_management_adr, engagement: engagement)

      expect {
        delete admin_adr_management_engagement_path(engagement)
      }.not_to change(AdrManagement::Engagement, :count)

      expect(flash[:alert]).to include("削除できません")
    end
  end
end
