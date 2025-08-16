require 'rails_helper'

RSpec.describe "API::MCP Slide Tools", type: :request do
  let(:api_token) { Rails.application.credentials.dig(:mcp, :api_token) }
  let(:headers) do
    {
      "Authorization" => "Bearer #{api_token}",
      "Content-Type" => "application/json"
    }
  end

  describe "create_slide_tool" do
    let(:slide_content) do
      <<~MARKDOWN
        ---
        title: API Test Slide
        slug: api-test-slide
        category: slide
        description: A slide created via MCP API
        published_date: 2025-08-16
        tags:
          - API
          - Testing
        ---

        # First Slide

        Content for the first slide

        ---

        # Second Slide

        Content for the second slide
      MARKDOWN
    end

    let(:request_body) do
      {
        jsonrpc: "2.0",
        id: "test-1",
        method: "tools/call",
        params: {
          name: "create_slide_tool",
          arguments: {
            content: slide_content
          }
        }
      }.to_json
    end

    it "creates a new slide" do
      expect {
        post api_mcp_path, params: request_body, headers: headers
      }.to change(Slide, :count).by(1)

      expect(response).to have_http_status(:ok)

      json_response = JSON.parse(response.body)
      expect(json_response["result"]["content"][0]["text"]).to include("Slide created successfully")
      expect(json_response["result"]["content"][0]["text"]).to include("API Test Slide")
    end
  end

  describe "update_slide_tool" do
    let!(:existing_slide) { create(:slide, :with_pages, slug: "existing-api-slide") }

    let(:updated_content) do
      <<~MARKDOWN
        ---
        title: Updated API Slide
        slug: existing-api-slide
        category: slide
        description: Updated via API
        published_date: 2025-08-20
        tags:
          - Updated
        ---

        # Updated Content

        New slide content
      MARKDOWN
    end

    let(:request_body) do
      {
        jsonrpc: "2.0",
        id: "test-2",
        method: "tools/call",
        params: {
          name: "update_slide_tool",
          arguments: {
            slug: "existing-api-slide",
            content: updated_content
          }
        }
      }.to_json
    end

    it "updates an existing slide" do
      post api_mcp_path, params: request_body, headers: headers

      expect(response).to have_http_status(:ok)

      json_response = JSON.parse(response.body)
      expect(json_response["result"]["content"][0]["text"]).to include("Slide updated successfully")
      expect(json_response["result"]["content"][0]["text"]).to include("Updated API Slide")

      updated_slide = Slide.find_by(slug: "existing-api-slide")
      expect(updated_slide.title).to eq("Updated API Slide")
    end
  end

  describe "find_slide_tool" do
    let!(:slide) { create(:slide, :with_pages, slug: "findable-slide", title: "Findable Slide") }

    let(:request_body) do
      {
        jsonrpc: "2.0",
        id: "test-3",
        method: "tools/call",
        params: {
          name: "find_slide_tool",
          arguments: {
            slug: "findable-slide"
          }
        }
      }.to_json
    end

    it "finds an existing slide" do
      post api_mcp_path, params: request_body, headers: headers

      expect(response).to have_http_status(:ok)

      json_response = JSON.parse(response.body)
      expect(json_response["result"]["content"][0]["text"]).to include("Slide found:")
      expect(json_response["result"]["content"][0]["text"]).to include("Findable Slide")
      expect(json_response["result"]["content"][0]["text"]).to include("Pages: 3")
    end
  end

  describe "list_slides_tool" do
    let!(:slide1) { create(:slide, :with_pages, title: "Slide 1", published_at: 2.days.ago) }
    let!(:slide2) { create(:slide, :draft, title: "Draft Slide") }

    let(:request_body) do
      {
        jsonrpc: "2.0",
        id: "test-4",
        method: "tools/call",
        params: {
          name: "list_slides_tool",
          arguments: {
            status: "published"
          }
        }
      }.to_json
    end

    it "lists slides based on criteria" do
      post api_mcp_path, params: request_body, headers: headers

      expect(response).to have_http_status(:ok)

      json_response = JSON.parse(response.body)
      expect(json_response["result"]["content"][0]["text"]).to include("Found")
      expect(json_response["result"]["content"][0]["text"]).to include("Slide 1")
      expect(json_response["result"]["content"][0]["text"]).not_to include("Draft Slide")
    end
  end

  describe "tools listing" do
    let(:request_body) do
      {
        jsonrpc: "2.0",
        id: "test-list",
        method: "tools/list"
      }.to_json
    end

    it "includes slide tools in the available tools list" do
      post api_mcp_path, params: request_body, headers: headers

      expect(response).to have_http_status(:ok)

      json_response = JSON.parse(response.body)
      tool_names = json_response["result"]["tools"].map { |tool| tool["name"] }

      expect(tool_names).to include("create_slide_tool")
      expect(tool_names).to include("update_slide_tool")
      expect(tool_names).to include("find_slide_tool")
      expect(tool_names).to include("list_slides_tool")
    end
  end
end
