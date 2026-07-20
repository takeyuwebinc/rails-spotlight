# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::AdrManagement::Projects", type: :request do
  before { sign_in_admin }

  let!(:engagement) { create(:adr_management_engagement) }

  describe "POST /admin/adr/engagements/:engagement_id/projects" do
    it "creates a project" do
      expect {
        post admin_adr_management_engagement_projects_path(engagement),
          params: { adr_management_project: { name: "保守開発2026年度", start_date: "2026-04-01", end_date: "2027-03-31" } }
      }.to change(engagement.projects, :count).by(1)
    end

    it "re-renders the form when the period is inverted" do
      post admin_adr_management_engagement_projects_path(engagement),
        params: { adr_management_project: { name: "P", start_date: "2027-01-01", end_date: "2026-01-01" } }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /admin/adr/engagements/:engagement_id/projects/:id" do
    it "deletes a project not referenced by adrs" do
      project = create(:adr_management_project, engagement: engagement)

      expect {
        delete admin_adr_management_engagement_project_path(engagement, project)
      }.to change(engagement.projects, :count).by(-1)
    end

    it "refuses to delete a project referenced by an adr" do
      project = create(:adr_management_project, engagement: engagement)
      create(:adr_management_adr, engagement: engagement, project: project)

      expect {
        delete admin_adr_management_engagement_project_path(engagement, project)
      }.not_to change(engagement.projects, :count)

      expect(flash[:alert]).to include("削除できません")
    end
  end
end
