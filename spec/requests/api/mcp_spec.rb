require "rails_helper"

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
          expect(json_response["result"]["serverInfo"]["name"]).to eq("spotlight-rails")
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

        it "returns available slide tools" do
          post api_mcp_path, params: request_body, headers: headers

          expect(response).to have_http_status(:success)

          json_response = JSON.parse(response.body)
          expect(json_response["jsonrpc"]).to eq("2.0")
          expect(json_response["id"]).to eq(2)

          tools = json_response["result"]["tools"]
          expect(tools).to be_an(Array)
          expect(tools.map { |t| t["name"] }).to include(
            "create_slide_tool",
            "update_slide_tool",
            "find_slide_tool",
            "list_slides_tool"
          )
        end
      end
    end

    context "with invalid authentication" do
      context "when no token is provided" do
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
          expect(json_response["error"]["message"]).to eq("Unauthorized")
        end
      end

      context "when invalid token is provided" do
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
          expect(json_response["error"]["message"]).to eq("Unauthorized")
        end
      end
    end
  end
end
