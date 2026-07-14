# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::WorkHour::Projects", type: :request do
  before { sign_in_admin }

  describe "GET /admin/work_hour/projects" do
    let!(:client) { create(:work_hour_client, name: "テストクライアント") }
    let!(:project1) { create(:work_hour_project, name: "案件A", client: client) }
    let!(:project2) { create(:work_hour_project, name: "案件B") }

    it "returns http success" do
      get admin_work_hour_projects_path
      expect(response).to have_http_status(:success)
    end

    it "displays all projects" do
      get admin_work_hour_projects_path
      expect(response.body).to include("案件A")
      expect(response.body).to include("案件B")
    end

    it "displays client name" do
      get admin_work_hour_projects_path
      expect(response.body).to include("テストクライアント")
    end

    it "renders without error when there is no project" do
      ::WorkHour::Project.delete_all

      get admin_work_hour_projects_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("案件がありません")
    end

    context "with budget and actual work entries" do
      let!(:budgeted) { create(:work_hour_project, name: "予算案件", budget_hours: 100) }

      it "displays the actual hours accumulated over all periods" do
        create(:work_hour_work_entry, project: budgeted, minutes: 90)
        create(:work_hour_work_entry, project: budgeted, minutes: 60)

        get admin_work_hour_projects_path
        expect(response.body).to include("2.5時間")
      end

      it "displays 0.0 hours for a project without entries" do
        get admin_work_hour_projects_path
        expect(response.body).to include("0.0時間")
      end

      it "excludes entries without a project from the actual hours" do
        create(:work_hour_work_entry, project: nil, minutes: 600)

        get admin_work_hour_projects_path
        expect(response.body).not_to include("10.0時間")
      end

      it "displays the consumption rate" do
        create(:work_hour_work_entry, project: budgeted, minutes: 3600) # 60時間

        get admin_work_hour_projects_path
        expect(response.body).to include("60%")
      end

      it "highlights a project at the caution rate" do
        create(:work_hour_work_entry, project: budgeted, minutes: 5400) # 90時間 = 90%

        get admin_work_hour_projects_path
        expect(response.body).to include("bg-amber-50")
        expect(response.body).to include("90%")
      end

      it "displays the uncapped rate and highlights a project over budget" do
        create(:work_hour_work_entry, project: budgeted, minutes: 7200) # 120時間 = 120%

        get admin_work_hour_projects_path
        expect(response.body).to include("bg-red-50")
        expect(response.body).to include("120%")
      end
    end

    context "with projects without budget" do
      it "renders no consumption rate and does not raise" do
        ::WorkHour::Project.update_all(budget_hours: nil)
        create(:work_hour_work_entry, project: project1, minutes: 3600)

        get admin_work_hour_projects_path
        expect(response).to have_http_status(:success)
        expect(response.body).not_to match(/\d+%/)
      end
    end

    it "does not issue more queries as the number of projects grows" do
      3.times do |i|
        project = create(:work_hour_project, name: "案件#{i}", budget_hours: 100)
        2.times { create(:work_hour_work_entry, project: project, minutes: 60) }
      end
      get admin_work_hour_projects_path # ビューのコンパイル等を先に済ませる

      baseline = count_queries { get admin_work_hour_projects_path }

      3.times do |i|
        project = create(:work_hour_project, name: "追加案件#{i}", budget_hours: 100)
        2.times { create(:work_hour_work_entry, project: project, minutes: 60) }
      end

      expect(count_queries { get admin_work_hour_projects_path }).to eq(baseline)
    end
  end

  describe "GET /admin/work_hour/projects/:id" do
    let!(:project) { create(:work_hour_project, name: "詳細案件") }
    let!(:estimate) { create(:work_hour_project_monthly_estimate, project: project, year_month: Date.new(2025, 1, 1), estimated_hours: 40) }

    it "returns http success" do
      get admin_work_hour_project_path(project)
      expect(response).to have_http_status(:success)
    end

    it "displays project details" do
      get admin_work_hour_project_path(project)
      expect(response.body).to include("詳細案件")
    end

    it "displays monthly estimates" do
      get admin_work_hour_project_path(project)
      expect(response.body).to include("40")
    end

    it "displays the budget summary" do
      project.update!(budget_hours: 100)
      create(:work_hour_work_entry, project: project, minutes: 3600) # 60時間

      get admin_work_hour_project_path(project)
      expect(response.body).to include("予算消化")
      expect(response.body).to include("100.0時間")
      expect(response.body).to include("60.0時間")
      expect(response.body).to include("60%")
    end

    it "displays monthly actual hours in descending order of target month" do
      create(:work_hour_work_entry, project: project, target_month: Date.new(2025, 1, 1), minutes: 60)
      create(:work_hour_work_entry, project: project, target_month: Date.new(2025, 1, 1), minutes: 90)
      create(:work_hour_work_entry, project: project, target_month: Date.new(2025, 2, 1), minutes: 30)

      get admin_work_hour_project_path(project)
      expect(response.body).to include("2025年01月")
      expect(response.body).to include("2.5時間")
      expect(response.body).to include("0.5時間")
      expect(response.body.index("2025年02月")).to be < response.body.index("2025年01月")
    end

    it "renders the monthly actual table empty when there is no entry" do
      get admin_work_hour_project_path(project)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("実績が登録されていません")
    end
  end

  describe "GET /admin/work_hour/projects/new" do
    it "returns http success" do
      get new_admin_work_hour_project_path
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
          post admin_work_hour_projects_path, params: valid_params
        }.to change(::WorkHour::Project, :count).by(1)
      end

      it "redirects to show page with notice" do
        post admin_work_hour_projects_path, params: valid_params
        expect(response).to redirect_to(admin_work_hour_project_path(::WorkHour::Project.last))
        expect(flash[:notice]).to eq("案件を作成しました。")
      end

      it "assigns correct attributes" do
        post admin_work_hour_projects_path, params: valid_params
        project = ::WorkHour::Project.last
        expect(project.code).to eq("new-project")
        expect(project.name).to eq("新規案件")
        expect(project.client).to eq(client)
        expect(project.color).to eq("#ff0000")
        expect(project.status).to eq("active")
      end
    end

    context "without budget_hours" do
      let(:params_without_budget) do
        {
          work_hour_project: {
            code: "no-budget-project",
            name: "予算未登録案件",
            color: "#ff0000",
            status: "active",
            budget_hours: ""
          }
        }
      end

      it "creates a project with nil budget_hours" do
        post admin_work_hour_projects_path, params: params_without_budget
        expect(::WorkHour::Project.last.budget_hours).to be_nil
      end
    end

    context "with budget_hours" do
      let(:params_with_budget) do
        {
          work_hour_project: {
            code: "budget-project",
            name: "予算登録案件",
            color: "#ff0000",
            status: "active",
            budget_hours: "120.5"
          }
        }
      end

      it "creates a project with the given budget_hours" do
        post admin_work_hour_projects_path, params: params_with_budget
        expect(::WorkHour::Project.last.budget_hours).to eq(120.5)
      end
    end

    context "with zero budget_hours" do
      let(:params_with_zero_budget) do
        {
          work_hour_project: {
            code: "zero-budget-project",
            name: "予算ゼロ案件",
            color: "#ff0000",
            status: "active",
            budget_hours: "0"
          }
        }
      end

      it "does not create a project" do
        expect {
          post admin_work_hour_projects_path, params: params_with_zero_budget
        }.not_to change(::WorkHour::Project, :count)
      end

      it "renders the form with an error message" do
        post admin_work_hour_projects_path, params: params_with_zero_budget
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("must be greater than 0")
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
          post admin_work_hour_projects_path, params: invalid_params
        }.not_to change(::WorkHour::Project, :count)
      end

      it "returns unprocessable entity" do
        post admin_work_hour_projects_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /admin/work_hour/projects/:id/edit" do
    let!(:project) { create(:work_hour_project) }

    it "returns http success" do
      get edit_admin_work_hour_project_path(project)
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
        patch admin_work_hour_project_path(project), params: valid_params
        project.reload
        expect(project.name).to eq("新名称")
        expect(project.color).to eq("#00ff00")
      end

      it "updates budget_hours" do
        patch admin_work_hour_project_path(project), params: { work_hour_project: { budget_hours: "120.5" } }
        expect(project.reload.budget_hours).to eq(120.5)
      end

      it "redirects to show page with notice" do
        patch admin_work_hour_project_path(project), params: valid_params
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
        patch admin_work_hour_project_path(project), params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /admin/work_hour/projects/:id" do
    let!(:project) { create(:work_hour_project) }

    it "deletes the project" do
      expect {
        delete admin_work_hour_project_path(project)
      }.to change(::WorkHour::Project, :count).by(-1)
    end

    it "redirects to index with notice" do
      delete admin_work_hour_project_path(project)
      expect(response).to redirect_to(admin_work_hour_projects_path)
      expect(flash[:notice]).to eq("案件を削除しました。")
    end
  end
end
