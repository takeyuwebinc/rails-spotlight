# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::WorkHour::MonthlyEstimates", type: :request do
  let(:credentials) { { username: "admin", password: "password" } }
  let(:auth_headers) do
    {
      "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(
        credentials[:username], credentials[:password]
      )
    }
  end

  before do
    allow(Rails.application.credentials).to receive(:dig).with(:admin, :username).and_return(credentials[:username])
    allow(Rails.application.credentials).to receive(:dig).with(:admin, :password).and_return(credentials[:password])
  end

  let!(:project) { create(:work_hour_project, name: "テスト案件") }

  describe "GET /admin/work_hour/projects/:project_id/monthly_estimates/new" do
    it "returns http success" do
      get new_admin_work_hour_project_monthly_estimate_path(project), headers: auth_headers
      expect(response).to have_http_status(:success)
    end

    it "displays form" do
      get new_admin_work_hour_project_monthly_estimate_path(project), headers: auth_headers
      expect(response.body).to include("見込み工数")
    end
  end

  describe "POST /admin/work_hour/projects/:project_id/monthly_estimates" do
    context "with valid params" do
      let(:valid_params) do
        {
          work_hour_project_monthly_estimate: {
            year_month: Date.new(2025, 1, 1),
            estimated_hours: 80
          }
        }
      end

      it "creates a new monthly estimate" do
        expect {
          post admin_work_hour_project_monthly_estimates_path(project), params: valid_params, headers: auth_headers
        }.to change(::WorkHour::ProjectMonthlyEstimate, :count).by(1)
      end

      it "redirects to project show page with notice" do
        post admin_work_hour_project_monthly_estimates_path(project), params: valid_params, headers: auth_headers
        expect(response).to redirect_to(admin_work_hour_project_path(project))
        expect(flash[:notice]).to eq("見込み工数を登録しました。")
      end

      it "assigns correct attributes" do
        post admin_work_hour_project_monthly_estimates_path(project), params: valid_params, headers: auth_headers
        estimate = ::WorkHour::ProjectMonthlyEstimate.last
        expect(estimate.project).to eq(project)
        expect(estimate.year_month).to eq(Date.new(2025, 1, 1))
        expect(estimate.estimated_hours).to eq(80)
      end
    end

    context "with invalid params" do
      let(:invalid_params) do
        {
          work_hour_project_monthly_estimate: {
            year_month: "",
            estimated_hours: nil
          }
        }
      end

      it "does not create a monthly estimate" do
        expect {
          post admin_work_hour_project_monthly_estimates_path(project), params: invalid_params, headers: auth_headers
        }.not_to change(::WorkHour::ProjectMonthlyEstimate, :count)
      end

      it "returns unprocessable entity" do
        post admin_work_hour_project_monthly_estimates_path(project), params: invalid_params, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /admin/work_hour/projects/:project_id/monthly_estimates/:id/edit" do
    let!(:estimate) { create(:work_hour_project_monthly_estimate, project: project, year_month: Date.new(2025, 1, 1)) }

    it "returns http success" do
      get edit_admin_work_hour_project_monthly_estimate_path(project, estimate), headers: auth_headers
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /admin/work_hour/projects/:project_id/monthly_estimates/:id" do
    let!(:estimate) { create(:work_hour_project_monthly_estimate, project: project, estimated_hours: 40) }

    context "with valid params" do
      let(:valid_params) do
        {
          work_hour_project_monthly_estimate: {
            estimated_hours: 100
          }
        }
      end

      it "updates the monthly estimate" do
        patch admin_work_hour_project_monthly_estimate_path(project, estimate), params: valid_params, headers: auth_headers
        estimate.reload
        expect(estimate.estimated_hours).to eq(100)
      end

      it "redirects to project show page with notice" do
        patch admin_work_hour_project_monthly_estimate_path(project, estimate), params: valid_params, headers: auth_headers
        expect(response).to redirect_to(admin_work_hour_project_path(project))
        expect(flash[:notice]).to eq("見込み工数を更新しました。")
      end
    end

    context "with invalid params" do
      let(:invalid_params) do
        {
          work_hour_project_monthly_estimate: {
            estimated_hours: nil
          }
        }
      end

      it "returns unprocessable entity" do
        patch admin_work_hour_project_monthly_estimate_path(project, estimate), params: invalid_params, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /admin/work_hour/projects/:project_id/monthly_estimates/:id" do
    let!(:estimate) { create(:work_hour_project_monthly_estimate, project: project) }

    it "deletes the monthly estimate" do
      expect {
        delete admin_work_hour_project_monthly_estimate_path(project, estimate), headers: auth_headers
      }.to change(::WorkHour::ProjectMonthlyEstimate, :count).by(-1)
    end

    it "redirects to project show page with notice" do
      delete admin_work_hour_project_monthly_estimate_path(project, estimate), headers: auth_headers
      expect(response).to redirect_to(admin_work_hour_project_path(project))
      expect(flash[:notice]).to eq("見込み工数を削除しました。")
    end
  end
end
