# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::WorkHour::Projects", type: :request do
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

  describe "GET /admin/work_hour/projects" do
    let!(:client) { create(:work_hour_client, name: "テストクライアント") }
    let!(:project1) { create(:work_hour_project, name: "案件A", client: client) }
    let!(:project2) { create(:work_hour_project, name: "案件B") }

    it "returns http success" do
      get admin_work_hour_projects_path, headers: auth_headers
      expect(response).to have_http_status(:success)
    end

    it "displays all projects" do
      get admin_work_hour_projects_path, headers: auth_headers
      expect(response.body).to include("案件A")
      expect(response.body).to include("案件B")
    end

    it "displays client name" do
      get admin_work_hour_projects_path, headers: auth_headers
      expect(response.body).to include("テストクライアント")
    end
  end

  describe "GET /admin/work_hour/projects/:id" do
    let!(:project) { create(:work_hour_project, name: "詳細案件") }
    let!(:estimate) { create(:work_hour_project_monthly_estimate, project: project, year_month: Date.new(2025, 1, 1), estimated_hours: 40) }

    it "returns http success" do
      get admin_work_hour_project_path(project), headers: auth_headers
      expect(response).to have_http_status(:success)
    end

    it "displays project details" do
      get admin_work_hour_project_path(project), headers: auth_headers
      expect(response.body).to include("詳細案件")
    end

    it "displays monthly estimates" do
      get admin_work_hour_project_path(project), headers: auth_headers
      expect(response.body).to include("40")
    end
  end

  describe "GET /admin/work_hour/projects/new" do
    it "returns http success" do
      get new_admin_work_hour_project_path, headers: auth_headers
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /admin/work_hour/projects" do
    let!(:client) { create(:work_hour_client) }

    context "with valid params" do
      let(:valid_params) do
        {
          work_hour_project: {
            code: "new-project",
            name: "新規案件",
            client_id: client.id,
            color: "#ff0000",
            status: "active"
          }
        }
      end

      it "creates a new project" do
        expect {
          post admin_work_hour_projects_path, params: valid_params, headers: auth_headers
        }.to change(::WorkHour::Project, :count).by(1)
      end

      it "redirects to show page with notice" do
        post admin_work_hour_projects_path, params: valid_params, headers: auth_headers
        expect(response).to redirect_to(admin_work_hour_project_path(::WorkHour::Project.last))
        expect(flash[:notice]).to eq("案件を作成しました。")
      end

      it "assigns correct attributes" do
        post admin_work_hour_projects_path, params: valid_params, headers: auth_headers
        project = ::WorkHour::Project.last
        expect(project.code).to eq("new-project")
        expect(project.name).to eq("新規案件")
        expect(project.client).to eq(client)
        expect(project.color).to eq("#ff0000")
        expect(project.status).to eq("active")
      end
    end

    context "with invalid params" do
      let(:invalid_params) do
        {
          work_hour_project: {
            code: "",
            name: ""
          }
        }
      end

      it "does not create a project" do
        expect {
          post admin_work_hour_projects_path, params: invalid_params, headers: auth_headers
        }.not_to change(::WorkHour::Project, :count)
      end

      it "returns unprocessable entity" do
        post admin_work_hour_projects_path, params: invalid_params, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /admin/work_hour/projects/:id/edit" do
    let!(:project) { create(:work_hour_project) }

    it "returns http success" do
      get edit_admin_work_hour_project_path(project), headers: auth_headers
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /admin/work_hour/projects/:id" do
    let!(:project) { create(:work_hour_project, name: "旧名称") }

    context "with valid params" do
      let(:valid_params) do
        {
          work_hour_project: {
            name: "新名称",
            color: "#00ff00"
          }
        }
      end

      it "updates the project" do
        patch admin_work_hour_project_path(project), params: valid_params, headers: auth_headers
        project.reload
        expect(project.name).to eq("新名称")
        expect(project.color).to eq("#00ff00")
      end

      it "redirects to show page with notice" do
        patch admin_work_hour_project_path(project), params: valid_params, headers: auth_headers
        expect(response).to redirect_to(admin_work_hour_project_path(project))
        expect(flash[:notice]).to eq("案件を更新しました。")
      end
    end

    context "with invalid params" do
      let(:invalid_params) do
        {
          work_hour_project: {
            name: ""
          }
        }
      end

      it "returns unprocessable entity" do
        patch admin_work_hour_project_path(project), params: invalid_params, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /admin/work_hour/projects/:id" do
    let!(:project) { create(:work_hour_project) }

    it "deletes the project" do
      expect {
        delete admin_work_hour_project_path(project), headers: auth_headers
      }.to change(::WorkHour::Project, :count).by(-1)
    end

    it "redirects to index with notice" do
      delete admin_work_hour_project_path(project), headers: auth_headers
      expect(response).to redirect_to(admin_work_hour_projects_path)
      expect(flash[:notice]).to eq("案件を削除しました。")
    end
  end
end
