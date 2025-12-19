# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin OmniAuth Callbacks", type: :request do
  before do
    OmniAuth.config.test_mode = true
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  describe "GET /admin/auth/google_oauth2/callback" do
    context "with valid takeyuweb.co.jp account" do
      before do
        OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
          provider: "google_oauth2",
          uid: "123456789",
          info: {
            email: "user@takeyuweb.co.jp",
            name: "Test User"
          },
          credentials: {
            token: "mock_token",
            expires_at: Time.now.to_i + 3600
          }
        })
      end

      it "logs in the user and redirects to admin root" do
        get "/admin/auth/google_oauth2/callback"

        expect(response).to redirect_to(admin_root_path)
        follow_redirect!
        expect(session[:admin_email]).to eq("user@takeyuweb.co.jp")
        expect(session[:admin_name]).to eq("Test User")
      end
    end

    context "with non-takeyuweb.co.jp account" do
      before do
        OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
          provider: "google_oauth2",
          uid: "123456789",
          info: {
            email: "user@other-domain.com",
            name: "Other User"
          },
          credentials: {
            token: "mock_token",
            expires_at: Time.now.to_i + 3600
          }
        })
      end

      it "rejects login and redirects to login page with error" do
        get "/admin/auth/google_oauth2/callback"

        expect(response).to redirect_to(admin_login_path)
        follow_redirect!
        expect(response.body).to include("このアカウントではログインできません")
        expect(session[:admin_email]).to be_nil
      end
    end

    context "when authentication fails" do
      before do
        OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials
      end

      it "redirects to failure path" do
        get "/admin/auth/google_oauth2/callback"

        # OmniAuth failure handling
        expect(response.status).to be_in([ 302, 404 ])
      end
    end
  end

  describe "GET /admin/auth/failure" do
    it "redirects to login page with error message" do
      get "/admin/auth/failure", params: { message: "invalid_credentials" }

      expect(response).to redirect_to(admin_login_path)
    end
  end
end
