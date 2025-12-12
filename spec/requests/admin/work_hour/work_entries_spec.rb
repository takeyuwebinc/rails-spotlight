# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::WorkHour::WorkEntries", type: :request do
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

  let!(:project) { create(:work_hour_project, name: "テスト案件", status: "active") }

  describe "GET /admin/work_hour/work_entries" do
    let!(:entry1) { create(:work_hour_work_entry, project: project, worked_on: Date.current, description: "作業1") }
    let!(:entry2) { create(:work_hour_work_entry, project: project, worked_on: Date.current - 1.week, description: "先週の作業") }

    it "returns http success" do
      get admin_work_hour_work_entries_path, headers: auth_headers
      expect(response).to have_http_status(:success)
    end

    it "displays current week entries by default" do
      get admin_work_hour_work_entries_path, headers: auth_headers
      expect(response.body).to include("作業1")
    end

    it "can filter by date" do
      get admin_work_hour_work_entries_path(date: Date.current - 1.week), headers: auth_headers
      expect(response.body).to include("先週の作業")
    end

    it "can switch to month view" do
      get admin_work_hour_work_entries_path(view_mode: "month"), headers: auth_headers
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /admin/work_hour/work_entries/new" do
    it "returns http success" do
      get new_admin_work_hour_work_entry_path, headers: auth_headers
      expect(response).to have_http_status(:success)
    end

    it "pre-fills date from params" do
      get new_admin_work_hour_work_entry_path(date: "2025-01-15"), headers: auth_headers
      expect(response.body).to include("2025-01-15")
    end
  end

  describe "POST /admin/work_hour/work_entries" do
    context "with valid params" do
      let(:valid_params) do
        {
          work_hour_work_entry: {
            project_id: project.id,
            worked_on: Date.new(2025, 1, 15),
            target_month: Date.new(2025, 1, 1),
            description: "開発作業",
            minutes: 120
          }
        }
      end

      it "creates a new work entry" do
        expect {
          post admin_work_hour_work_entries_path, params: valid_params, headers: auth_headers
        }.to change(::WorkHour::WorkEntry, :count).by(1)
      end

      it "redirects to index with notice" do
        post admin_work_hour_work_entries_path, params: valid_params, headers: auth_headers
        expect(response).to redirect_to(admin_work_hour_work_entries_path(date: Date.new(2025, 1, 15)))
        expect(flash[:notice]).to eq("工数を登録しました。")
      end

      it "assigns correct attributes" do
        post admin_work_hour_work_entries_path, params: valid_params, headers: auth_headers
        entry = ::WorkHour::WorkEntry.last
        expect(entry.project).to eq(project)
        expect(entry.worked_on).to eq(Date.new(2025, 1, 15))
        expect(entry.target_month).to eq(Date.new(2025, 1, 1))
        expect(entry.description).to eq("開発作業")
        expect(entry.minutes).to eq(120)
      end
    end

    context "without project (その他)" do
      let(:valid_params) do
        {
          work_hour_work_entry: {
            project_id: nil,
            worked_on: Date.new(2025, 1, 15),
            target_month: Date.new(2025, 1, 1),
            description: "ミーティング",
            minutes: 60
          }
        }
      end

      it "creates a work entry without project" do
        expect {
          post admin_work_hour_work_entries_path, params: valid_params, headers: auth_headers
        }.to change(::WorkHour::WorkEntry, :count).by(1)

        entry = ::WorkHour::WorkEntry.last
        expect(entry.project).to be_nil
      end
    end

    context "with invalid params" do
      let(:invalid_params) do
        {
          work_hour_work_entry: {
            worked_on: nil,
            target_month: nil,
            minutes: nil
          }
        }
      end

      it "does not create a work entry" do
        expect {
          post admin_work_hour_work_entries_path, params: invalid_params, headers: auth_headers
        }.not_to change(::WorkHour::WorkEntry, :count)
      end

      it "returns unprocessable entity" do
        post admin_work_hour_work_entries_path, params: invalid_params, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /admin/work_hour/work_entries/:id/edit" do
    let!(:entry) { create(:work_hour_work_entry, project: project) }

    it "returns http success" do
      get edit_admin_work_hour_work_entry_path(entry), headers: auth_headers
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /admin/work_hour/work_entries/:id" do
    let!(:entry) { create(:work_hour_work_entry, project: project, description: "旧説明", minutes: 60) }

    context "with valid params" do
      let(:valid_params) do
        {
          work_hour_work_entry: {
            description: "新説明",
            minutes: 120
          }
        }
      end

      it "updates the work entry" do
        patch admin_work_hour_work_entry_path(entry), params: valid_params, headers: auth_headers
        entry.reload
        expect(entry.description).to eq("新説明")
        expect(entry.minutes).to eq(120)
      end

      it "redirects to index with notice" do
        patch admin_work_hour_work_entry_path(entry), params: valid_params, headers: auth_headers
        expect(response).to redirect_to(admin_work_hour_work_entries_path(date: entry.worked_on))
        expect(flash[:notice]).to eq("工数を更新しました。")
      end
    end

    context "with invalid params" do
      let(:invalid_params) do
        {
          work_hour_work_entry: {
            minutes: nil
          }
        }
      end

      it "returns unprocessable entity" do
        patch admin_work_hour_work_entry_path(entry), params: invalid_params, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /admin/work_hour/work_entries/:id" do
    let!(:entry) { create(:work_hour_work_entry, project: project, worked_on: Date.new(2025, 1, 15)) }

    it "deletes the work entry" do
      expect {
        delete admin_work_hour_work_entry_path(entry), headers: auth_headers
      }.to change(::WorkHour::WorkEntry, :count).by(-1)
    end

    it "redirects to index with notice" do
      delete admin_work_hour_work_entry_path(entry), headers: auth_headers
      expect(response).to redirect_to(admin_work_hour_work_entries_path(date: Date.new(2025, 1, 15)))
      expect(flash[:notice]).to eq("工数を削除しました。")
    end
  end
end
