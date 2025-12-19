# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin Authentication", type: :request do
  describe "GET /admin" do
    context "when not logged in" do
      it "redirects to login page" do
        get admin_root_path

        expect(response).to redirect_to(admin_login_path)
      end
    end

    context "when logged in" do
      before { sign_in_admin }

      it "allows access to admin dashboard" do
        get admin_root_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /admin/login" do
    it "displays the login page" do
      get admin_login_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Googleでログイン")
    end

    context "when already logged in" do
      before { sign_in_admin }

      it "redirects to admin root" do
        get admin_login_path
        expect(response).to redirect_to(admin_root_path)
      end
    end
  end

  describe "DELETE /admin/logout" do
    before { sign_in_admin }

    it "clears session and redirects to login" do
      delete admin_logout_path

      expect(response).to redirect_to(admin_login_path)
      follow_redirect!
      expect(response.body).to include("ログアウトしました")
    end
  end
end
