# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Dashboard", type: :request do
  let(:credentials) { { username: "admin", password: "password" } }

  before do
    allow(Rails.application.credentials).to receive(:dig).with(:admin, :username).and_return(credentials[:username])
    allow(Rails.application.credentials).to receive(:dig).with(:admin, :password).and_return(credentials[:password])
  end

  describe "GET /admin" do
    context "without authentication" do
      it "returns unauthorized" do
        get admin_root_path
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with valid authentication" do
      let(:auth_headers) do
        {
          "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(
            credentials[:username], credentials[:password]
          )
        }
      end

      before { get admin_root_path, headers: auth_headers }

      it "returns http success" do
        expect(response).to have_http_status(:success)
      end

      it "displays dashboard title" do
        expect(response.body).to include("ダッシュボード")
      end

      it "displays availability summary card" do
        expect(response.body).to include("今月の稼働率")
      end

      it "displays current month hours card" do
        expect(response.body).to include("今月の工数")
      end

      it "displays active projects card" do
        expect(response.body).to include("アクティブ案件")
      end

      it "displays status card" do
        expect(response.body).to include("ステータス")
      end

      it "displays future availability section" do
        expect(response.body).to include("今後3カ月の稼働予定")
      end

      it "displays recent work entries section" do
        expect(response.body).to include("最近の工数登録")
      end

      it "displays quick action links" do
        expect(response.body).to include("クイックアクション")
        expect(response.body).to include("工数を登録")
        expect(response.body).to include("案件を追加")
        expect(response.body).to include("CSVインポート")
      end

      it "displays navigation links" do
        expect(response.body).to include("工数カレンダー")
        expect(response.body).to include("案件")
        expect(response.body).to include("クライアント")
        expect(response.body).to include("CSV")
      end
    end

    context "with data" do
      let(:auth_headers) do
        {
          "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(
            credentials[:username], credentials[:password]
          )
        }
      end

      let!(:client) { create(:work_hour_client) }
      let!(:project) { create(:work_hour_project, client: client, status: "active") }
      let!(:work_entry) do
        create(:work_hour_work_entry,
               project: project,
               worked_on: Date.current,
               target_month: Date.current.beginning_of_month,
               minutes: 120,
               description: "テスト作業")
      end

      before do
        create(:work_hour_project_monthly_estimate,
               project: project,
               year_month: Date.current.beginning_of_month,
               estimated_hours: 80)
        get admin_root_path, headers: auth_headers
      end

      it "displays active project" do
        expect(response.body).to include(project.name)
      end

      it "displays recent work entry" do
        expect(response.body).to include("テスト作業")
      end

      it "calculates availability rate" do
        expect(response.body).to include("50%")
      end

      it "displays current month hours" do
        expect(response.body).to include("2.0h")
      end
    end
  end
end
