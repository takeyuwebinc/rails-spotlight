# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::WorkHour::Csv", type: :request do
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

  describe "GET /admin/work_hour/csv" do
    it "returns http success" do
      get admin_work_hour_csv_index_path, headers: auth_headers
      expect(response).to have_http_status(:success)
    end

    it "displays import forms" do
      get admin_work_hour_csv_index_path, headers: auth_headers
      expect(response.body).to include("案件インポート")
      expect(response.body).to include("工数実績インポート")
    end

    it "displays export form" do
      get admin_work_hour_csv_index_path, headers: auth_headers
      expect(response.body).to include("工数実績エクスポート")
    end
  end

  describe "POST /admin/work_hour/csv/import_projects" do
    context "without file" do
      it "redirects with alert" do
        post import_projects_admin_work_hour_csv_index_path, headers: auth_headers
        expect(response).to redirect_to(admin_work_hour_csv_index_path)
        expect(flash[:alert]).to eq("ファイルを選択してください。")
      end
    end

    context "with valid CSV file" do
      let(:csv_content) do
        <<~CSV
          プロジェクトコード,プロジェクト名,発注元,カラー,期間from,期間to,運用ステータス
          proj-001,テストプロジェクト,テストクライアント,#ff0000,2025/01/01,2025/12/31,運用中
          proj-002,別のプロジェクト,テストクライアント,#00ff00,2025/02/01,,終了
        CSV
      end

      let(:file) do
        Rack::Test::UploadedFile.new(
          StringIO.new(csv_content),
          "text/csv",
          original_filename: "projects.csv"
        )
      end

      it "imports projects and redirects with notice" do
        expect {
          post import_projects_admin_work_hour_csv_index_path,
               params: { file: file },
               headers: auth_headers
        }.to change(::WorkHour::Project, :count).by(2)

        expect(response).to redirect_to(admin_work_hour_csv_index_path)
        expect(flash[:notice]).to include("案件をインポートしました")
      end

      it "creates client from 発注元" do
        expect {
          post import_projects_admin_work_hour_csv_index_path,
               params: { file: file },
               headers: auth_headers
        }.to change(::WorkHour::Client, :count).by(1)

        client = ::WorkHour::Client.find_by(name: "テストクライアント")
        expect(client).to be_present
      end

      it "assigns correct attributes to project" do
        post import_projects_admin_work_hour_csv_index_path,
             params: { file: file },
             headers: auth_headers

        project = ::WorkHour::Project.find_by(code: "proj-001")
        expect(project.name).to eq("テストプロジェクト")
        expect(project.color).to eq("#ff0000")
        expect(project.start_date).to eq(Date.new(2025, 1, 1))
        expect(project.end_date).to eq(Date.new(2025, 12, 31))
        expect(project.status).to eq("active")
      end

      it "parses 終了 status as closed" do
        post import_projects_admin_work_hour_csv_index_path,
             params: { file: file },
             headers: auth_headers

        project = ::WorkHour::Project.find_by(code: "proj-002")
        expect(project.status).to eq("closed")
      end
    end

    context "with Japanese date format" do
      let(:csv_content) do
        <<~CSV
          プロジェクトコード,プロジェクト名,発注元,カラー,期間from,期間to,運用ステータス
          proj-jp,日本語日付プロジェクト,,#6366f1,2025年01月15日,2025年03月31日,運用中
        CSV
      end

      let(:file) do
        Rack::Test::UploadedFile.new(
          StringIO.new(csv_content),
          "text/csv",
          original_filename: "projects.csv"
        )
      end

      it "parses Japanese date format" do
        post import_projects_admin_work_hour_csv_index_path,
             params: { file: file },
             headers: auth_headers

        project = ::WorkHour::Project.find_by(code: "proj-jp")
        expect(project.start_date).to eq(Date.new(2025, 1, 15))
        expect(project.end_date).to eq(Date.new(2025, 3, 31))
      end
    end

    context "updating existing project" do
      let!(:existing_project) { create(:work_hour_project, code: "proj-existing", name: "旧名称") }

      let(:csv_content) do
        <<~CSV
          プロジェクトコード,プロジェクト名,発注元,カラー,期間from,期間to,運用ステータス
          proj-existing,新名称,新クライアント,#0000ff,,,運用中
        CSV
      end

      let(:file) do
        Rack::Test::UploadedFile.new(
          StringIO.new(csv_content),
          "text/csv",
          original_filename: "projects.csv"
        )
      end

      it "updates existing project" do
        expect {
          post import_projects_admin_work_hour_csv_index_path,
               params: { file: file },
               headers: auth_headers
        }.not_to change(::WorkHour::Project, :count)

        existing_project.reload
        expect(existing_project.name).to eq("新名称")
        expect(existing_project.color).to eq("#0000ff")
      end

      it "reports update count" do
        post import_projects_admin_work_hour_csv_index_path,
             params: { file: file },
             headers: auth_headers

        expect(flash[:notice]).to include("更新: 1件")
      end
    end

    context "with BOM in CSV" do
      let(:csv_content) do
        "\xEF\xBB\xBF" + <<~CSV
          プロジェクトコード,プロジェクト名,発注元,カラー,期間from,期間to,運用ステータス
          proj-bom,BOMテスト,,#6366f1,,,運用中
        CSV
      end

      let(:file) do
        Rack::Test::UploadedFile.new(
          StringIO.new(csv_content),
          "text/csv",
          original_filename: "projects.csv"
        )
      end

      it "handles BOM correctly" do
        post import_projects_admin_work_hour_csv_index_path,
             params: { file: file },
             headers: auth_headers

        project = ::WorkHour::Project.find_by(code: "proj-bom")
        expect(project).to be_present
      end
    end
  end

  describe "POST /admin/work_hour/csv/import_work_entries" do
    let!(:project) { create(:work_hour_project, code: "proj-work") }

    context "without file" do
      it "redirects with alert" do
        post import_work_entries_admin_work_hour_csv_index_path, headers: auth_headers
        expect(response).to redirect_to(admin_work_hour_csv_index_path)
        expect(flash[:alert]).to eq("ファイルを選択してください。")
      end
    end

    context "with valid CSV file" do
      let(:csv_content) do
        <<~CSV
          対象月,工数登録日,プロジェクト,プロジェクトコード,業務内容,工数実績(分)
          2025年01月,2025年01月15日,テストプロジェクト,proj-work,開発作業,120
          2025年01月,2025年01月16日,テストプロジェクト,proj-work,テスト作業,60
        CSV
      end

      let(:file) do
        Rack::Test::UploadedFile.new(
          StringIO.new(csv_content),
          "text/csv",
          original_filename: "work_entries.csv"
        )
      end

      it "imports work entries and redirects with notice" do
        expect {
          post import_work_entries_admin_work_hour_csv_index_path,
               params: { file: file },
               headers: auth_headers
        }.to change(::WorkHour::WorkEntry, :count).by(2)

        expect(response).to redirect_to(admin_work_hour_csv_index_path)
        expect(flash[:notice]).to include("工数実績をインポートしました")
      end

      it "assigns correct attributes to work entry" do
        post import_work_entries_admin_work_hour_csv_index_path,
             params: { file: file },
             headers: auth_headers

        entry = ::WorkHour::WorkEntry.find_by(description: "開発作業")
        expect(entry.project).to eq(project)
        expect(entry.target_month).to eq(Date.new(2025, 1, 1))
        expect(entry.worked_on).to eq(Date.new(2025, 1, 15))
        expect(entry.minutes).to eq(120)
      end
    end

    context "with unknown project code" do
      let(:csv_content) do
        <<~CSV
          対象月,工数登録日,プロジェクト,プロジェクトコード,業務内容,工数実績(分)
          2025年01月,2025年01月15日,不明プロジェクト,unknown-proj,作業,60
        CSV
      end

      let(:file) do
        Rack::Test::UploadedFile.new(
          StringIO.new(csv_content),
          "text/csv",
          original_filename: "work_entries.csv"
        )
      end

      it "creates work entry without project" do
        post import_work_entries_admin_work_hour_csv_index_path,
             params: { file: file },
             headers: auth_headers

        entry = ::WorkHour::WorkEntry.find_by(description: "作業")
        expect(entry).to be_present
        expect(entry.project).to be_nil
      end
    end
  end

  describe "GET /admin/work_hour/csv/export_work_entries" do
    let!(:project) { create(:work_hour_project, code: "proj-export", name: "エクスポート案件") }
    let!(:entry1) do
      create(:work_hour_work_entry,
             project: project,
             target_month: Date.new(2025, 1, 1),
             worked_on: Date.new(2025, 1, 15),
             description: "作業1",
             minutes: 120)
    end
    let!(:entry2) do
      create(:work_hour_work_entry,
             project: project,
             target_month: Date.new(2025, 2, 1),
             worked_on: Date.new(2025, 2, 10),
             description: "作業2",
             minutes: 60)
    end

    it "returns CSV file" do
      get export_work_entries_admin_work_hour_csv_index_path,
          params: { start_month: "2025-01", end_month: "2025-02" },
          headers: auth_headers

      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("text/csv")
    end

    it "includes correct filename" do
      get export_work_entries_admin_work_hour_csv_index_path,
          params: { start_month: "2025-01", end_month: "2025-02" },
          headers: auth_headers

      expect(response.headers["Content-Disposition"]).to include("work_entries_202501_202502.csv")
    end

    it "includes work entries in response body" do
      get export_work_entries_admin_work_hour_csv_index_path,
          params: { start_month: "2025-01", end_month: "2025-02" },
          headers: auth_headers

      expect(response.body).to include("エクスポート案件")
      expect(response.body).to include("作業1")
      expect(response.body).to include("作業2")
    end

    it "filters by project_id when specified" do
      other_project = create(:work_hour_project, code: "proj-other")
      create(:work_hour_work_entry,
             project: other_project,
             target_month: Date.new(2025, 1, 1),
             worked_on: Date.new(2025, 1, 20),
             description: "他案件作業",
             minutes: 30)

      get export_work_entries_admin_work_hour_csv_index_path,
          params: { start_month: "2025-01", end_month: "2025-02", project_id: project.id },
          headers: auth_headers

      expect(response.body).to include("作業1")
      expect(response.body).not_to include("他案件作業")
    end

    it "filters by date range" do
      get export_work_entries_admin_work_hour_csv_index_path,
          params: { start_month: "2025-01", end_month: "2025-01" },
          headers: auth_headers

      expect(response.body).to include("作業1")
      expect(response.body).not_to include("作業2")
    end
  end
end
