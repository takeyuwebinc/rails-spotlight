require 'rails_helper'

RSpec.describe "Api::Mcp", type: :request do
  describe "POST /api/mcp" do
    let(:valid_token) { Rails.application.credentials.dig(:mcp, :api_token) }
    let(:headers) { { "Authorization" => "Bearer #{valid_token}", "Content-Type" => "application/json" } }

    context "with valid authentication" do
      context "when handling server info request" do
        let(:request_body) do
          {
            jsonrpc: "2.0",
            method: "initialize",
            id: 1
          }.to_json
        end

        it "returns server information" do
          post api_mcp_path, params: request_body, headers: headers

          expect(response).to have_http_status(:success)

          json_response = JSON.parse(response.body)
          expect(json_response["jsonrpc"]).to eq("2.0")
          expect(json_response["id"]).to eq(1)
          expect(json_response["result"]["protocolVersion"]).to eq("2024-11-05")
          expect(json_response["result"]["serverInfo"]["name"]).to eq("spotlight-rails-articles")
        end
      end

      context "when handling tools list request" do
        let(:request_body) do
          {
            jsonrpc: "2.0",
            method: "tools/list",
            id: 2
          }.to_json
        end

        it "returns available tools" do
          post api_mcp_path, params: request_body, headers: headers

          expect(response).to have_http_status(:success)

          json_response = JSON.parse(response.body)
          expect(json_response["jsonrpc"]).to eq("2.0")
          expect(json_response["id"]).to eq(2)

          tools = json_response["result"]["tools"]
          expect(tools).to be_an(Array)
          expect(tools.map { |t| t["name"] }).to include("create_article_tool", "update_article_tool", "find_article_tool")
        end
      end

      context "when calling create_article_tool" do
        let(:request_body) do
          {
            jsonrpc: "2.0",
            method: "tools/call",
            params: {
              name: "create_article_tool",
              arguments: {
                content: <<~MARKDOWN
                  ---
                  title: "Test Article"
                  slug: test-article
                  category: article
                  description: "A test article"
                  published_date: 2025-01-12
                  tags:
                    - Rails
                    - Testing
                  ---

                  ## Test Content

                  This is a test article.
                MARKDOWN
              }
            },
            id: 3
          }.to_json
        end

        it "creates a new article" do
          expect {
            post api_mcp_path, params: request_body, headers: headers
          }.to change(Article, :count).by(1)

          expect(response).to have_http_status(:success)

          json_response = JSON.parse(response.body)
          expect(json_response["jsonrpc"]).to eq("2.0")
          expect(json_response["id"]).to eq(3)
          expect(json_response["result"]["content"][0]["text"]).to include("Article created successfully")

          article = Article.last
          expect(article.title).to eq("Test Article")
          expect(article.slug).to eq("test-article")
          expect(article.tags.map(&:name)).to match_array([ "Rails", "Testing" ])
        end
      end

      context "when handling invalid JSON-RPC request" do
        let(:request_body) { "invalid json" }

        it "returns JSON-RPC parse error" do
          post api_mcp_path, params: request_body, headers: headers

          expect(response).to have_http_status(:success)

          json_response = JSON.parse(response.body)
          expect(json_response["error"]["code"]).to eq(-32700)
          expect(json_response["error"]["message"]).to eq("Parse error")
        end
      end

      context "when server raises an error" do
        let(:request_body) do
          {
            jsonrpc: "2.0",
            method: "unknown_method",
            id: 4
          }.to_json
        end

        before do
          allow_any_instance_of(MCP::Server).to receive(:handle_json).and_raise(StandardError.new("Test error"))
        end

        it "returns internal server error" do
          post api_mcp_path, params: request_body, headers: headers

          expect(response).to have_http_status(:internal_server_error)

          json_response = JSON.parse(response.body)
          expect(json_response["error"]["code"]).to eq(-32603)
          expect(json_response["error"]["message"]).to eq("Internal error")
          expect(json_response["error"]["data"]["details"]).to eq("Test error")
        end
      end
    end

    context "with invalid authentication" do
      context "when token is missing" do
        let(:headers) { { "Content-Type" => "application/json" } }
        let(:request_body) do
          {
            jsonrpc: "2.0",
            method: "initialize",
            id: 1
          }.to_json
        end

        it "returns unauthorized error" do
          post api_mcp_path, params: request_body, headers: headers

          expect(response).to have_http_status(:unauthorized)

          json_response = JSON.parse(response.body)
          expect(json_response["error"]["code"]).to eq(-32603)
          expect(json_response["error"]["message"]).to eq("Unauthorized")
          expect(json_response["error"]["data"]["details"]).to eq("Invalid or missing authentication token")
        end
      end

      context "when token is invalid" do
        let(:headers) { { "Authorization" => "Bearer invalid-token", "Content-Type" => "application/json" } }
        let(:request_body) do
          {
            jsonrpc: "2.0",
            method: "initialize",
            id: 1
          }.to_json
        end

        it "returns unauthorized error" do
          post api_mcp_path, params: request_body, headers: headers

          expect(response).to have_http_status(:unauthorized)

          json_response = JSON.parse(response.body)
          expect(json_response["error"]["code"]).to eq(-32603)
          expect(json_response["error"]["message"]).to eq("Unauthorized")
        end
      end
    end

    context "with non-Bearer authentication scheme" do
      let(:headers) { { "Authorization" => "Basic #{valid_token}", "Content-Type" => "application/json" } }
      let(:request_body) do
        {
          jsonrpc: "2.0",
          method: "initialize",
          id: 1
        }.to_json
      end

      it "returns unauthorized error" do
        post api_mcp_path, params: request_body, headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
