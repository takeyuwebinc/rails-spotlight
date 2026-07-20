# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::AdrManagement::Clients", type: :request do
  describe "authentication" do
    it "redirects unauthenticated access to login" do
      get admin_adr_management_clients_path
      expect(response).to redirect_to(admin_login_path)
    end
  end

  context "when signed in" do
    before { sign_in_admin }

    describe "GET /admin/adr/clients" do
      it "lists clients" do
        create(:adr_management_client, code: "acme", name: "ACME商事")

        get admin_adr_management_clients_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include("acme", "ACME商事")
      end
    end

    describe "POST /admin/adr/clients" do
      it "creates a client with a shared client" do
        expect {
          post admin_adr_management_clients_path,
            params: { adr_management_client: { code: "acme", name: "ACME商事" } }
        }.to change(AdrManagement::Client, :count).by(1)
          .and change(Client, :count).by(1)

        expect(response).to redirect_to(admin_adr_management_clients_path)
      end

      it "re-renders the form on validation errors" do
        post admin_adr_management_clients_path,
          params: { adr_management_client: { code: "", name: "" } }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    describe "PATCH /admin/adr/clients/:id" do
      it "renames the shared client" do
        client = create(:adr_management_client, code: "acme", name: "旧名称")

        patch admin_adr_management_client_path(client),
          params: { adr_management_client: { code: "acme", name: "新名称" } }

        expect(client.reload.name).to eq("新名称")
      end
    end

    describe "DELETE /admin/adr/clients/:id" do
      it "deletes an empty client but keeps the shared client" do
        client = create(:adr_management_client)

        expect {
          delete admin_adr_management_client_path(client)
        }.to change(AdrManagement::Client, :count).by(-1)
          .and change(Client, :count).by(0)
      end

      it "refuses to delete a client with engagements" do
        client = create(:adr_management_client)
        create(:adr_management_engagement, client: client)

        expect {
          delete admin_adr_management_client_path(client)
        }.not_to change(AdrManagement::Client, :count)

        expect(flash[:alert]).to include("削除できません")
      end
    end
  end
end
