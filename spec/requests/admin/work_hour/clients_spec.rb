# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::WorkHour::Clients", type: :request do
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

  describe "GET /admin/work_hour/clients" do
    let!(:client1) { create(:work_hour_client, name: "クライアントA") }
    let!(:client2) { create(:work_hour_client, name: "クライアントB") }

    it "returns http success" do
      get admin_work_hour_clients_path, headers: auth_headers
      expect(response).to have_http_status(:success)
    end

    it "displays all clients" do
      get admin_work_hour_clients_path, headers: auth_headers
      expect(response.body).to include("クライアントA")
      expect(response.body).to include("クライアントB")
    end
  end

  describe "GET /admin/work_hour/clients/:id" do
    let!(:client) { create(:work_hour_client, name: "詳細クライアント") }

    it "returns http success" do
      get admin_work_hour_client_path(client), headers: auth_headers
      expect(response).to have_http_status(:success)
    end

    it "displays client details" do
      get admin_work_hour_client_path(client), headers: auth_headers
      expect(response.body).to include("詳細クライアント")
    end
  end

  describe "GET /admin/work_hour/clients/new" do
    it "returns http success" do
      get new_admin_work_hour_client_path, headers: auth_headers
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /admin/work_hour/clients" do
    context "with valid params" do
      let(:valid_params) do
        {
          work_hour_client: {
            code: "new-client",
            name: "新規クライアント"
          }
        }
      end

      it "creates a new client" do
        expect {
          post admin_work_hour_clients_path, params: valid_params, headers: auth_headers
        }.to change(::WorkHour::Client, :count).by(1)
      end

      it "redirects to index with notice" do
        post admin_work_hour_clients_path, params: valid_params, headers: auth_headers
        expect(response).to redirect_to(admin_work_hour_clients_path)
        expect(flash[:notice]).to eq("クライアントを作成しました。")
      end
    end

    context "with invalid params" do
      let(:invalid_params) do
        {
          work_hour_client: {
            code: "",
            name: ""
          }
        }
      end

      it "does not create a client" do
        expect {
          post admin_work_hour_clients_path, params: invalid_params, headers: auth_headers
        }.not_to change(::WorkHour::Client, :count)
      end

      it "returns unprocessable entity" do
        post admin_work_hour_clients_path, params: invalid_params, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /admin/work_hour/clients/:id/edit" do
    let!(:client) { create(:work_hour_client) }

    it "returns http success" do
      get edit_admin_work_hour_client_path(client), headers: auth_headers
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /admin/work_hour/clients/:id" do
    let!(:client) { create(:work_hour_client, name: "旧名称") }

    context "with valid params" do
      let(:valid_params) do
        {
          work_hour_client: {
            name: "新名称"
          }
        }
      end

      it "updates the client" do
        patch admin_work_hour_client_path(client), params: valid_params, headers: auth_headers
        client.reload
        expect(client.name).to eq("新名称")
      end

      it "redirects to index with notice" do
        patch admin_work_hour_client_path(client), params: valid_params, headers: auth_headers
        expect(response).to redirect_to(admin_work_hour_clients_path)
        expect(flash[:notice]).to eq("クライアントを更新しました。")
      end
    end

    context "with invalid params" do
      let(:invalid_params) do
        {
          work_hour_client: {
            name: ""
          }
        }
      end

      it "returns unprocessable entity" do
        patch admin_work_hour_client_path(client), params: invalid_params, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /admin/work_hour/clients/:id" do
    let!(:client) { create(:work_hour_client) }

    it "deletes the client" do
      expect {
        delete admin_work_hour_client_path(client), headers: auth_headers
      }.to change(::WorkHour::Client, :count).by(-1)
    end

    it "redirects to index with notice" do
      delete admin_work_hour_client_path(client), headers: auth_headers
      expect(response).to redirect_to(admin_work_hour_clients_path)
      expect(flash[:notice]).to eq("クライアントを削除しました。")
    end
  end
end
