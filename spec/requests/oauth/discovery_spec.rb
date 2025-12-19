# frozen_string_literal: true

require "rails_helper"

RSpec.describe "OAuth Discovery Endpoints", type: :request do
  describe "GET /.well-known/oauth-protected-resource" do
    it "returns protected resource metadata" do
      get "/.well-known/oauth-protected-resource"

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json["resource"]).to include("/api/mcp")
      expect(json["authorization_servers"]).to be_an(Array)
      # authorization_servers should be the issuer URL (base URL), not the metadata URL
      # Clients will append /.well-known/oauth-authorization-server to discover metadata
      expect(json["authorization_servers"].first).not_to include("/.well-known/")
      expect(json["authorization_servers"].first).to eq("http://www.example.com")
      expect(json["scopes_supported"]).to include("mcp")
      expect(json["bearer_methods_supported"]).to include("header")
    end

    it "returns correct content type" do
      get "/.well-known/oauth-protected-resource"

      expect(response.content_type).to include("application/json")
    end
  end

  describe "GET /.well-known/oauth-authorization-server" do
    it "returns authorization server metadata" do
      get "/.well-known/oauth-authorization-server"

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json["issuer"]).to be_present
      expect(json["authorization_endpoint"]).to include("/oauth/authorize")
      expect(json["token_endpoint"]).to include("/oauth/token")
      # DCR is disabled - registration_endpoint should not be present
      expect(json["registration_endpoint"]).to be_nil
      expect(json["scopes_supported"]).to include("mcp")
      expect(json["response_types_supported"]).to include("code")
      expect(json["grant_types_supported"]).to include("authorization_code")
      expect(json["grant_types_supported"]).to include("refresh_token")
      expect(json["code_challenge_methods_supported"]).to include("S256")
    end

    it "returns correct content type" do
      get "/.well-known/oauth-authorization-server"

      expect(response.content_type).to include("application/json")
    end
  end

  describe "POST /oauth/applications (Dynamic Client Registration)" do
    it "is disabled and returns 404" do
      post "/oauth/applications",
           params: { client_name: "Test" }.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:not_found)
    end
  end
end
