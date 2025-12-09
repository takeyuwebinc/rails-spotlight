require "rails_helper"

RSpec.describe "API::MCP Project Tools", type: :request do
  let(:api_token) { Rails.application.credentials.dig(:mcp, :api_token) }
  let(:headers) do
    {
      "Authorization" => "Bearer #{api_token}",
      "Content-Type" => "application/json"
    }
  end

  describe "create_project_tool" do
    let(:project_content) do
      <<~MARKDOWN
        ---
        title: API Test Project
        category: project
        icon: fa-solid fa-rocket
        color: purple
        technologies: Ruby, Rails, PostgreSQL
        position: 100
        published_date: 2025-08-16
        ---

        This is a project created via MCP API.
        It demonstrates the capabilities of our platform.
      MARKDOWN
    end

    let(:request_body) do
      {
        jsonrpc: "2.0",
        id: "test-1",
        method: "tools/call",
        params: {
          name: "create_project_tool",
          arguments: {
            content: project_content
          }
        }
      }.to_json
    end

    it "creates a new project" do
      expect {
        post api_mcp_path, params: request_body, headers: headers
      }.to change(Project, :count).by(1)

      expect(response).to have_http_status(:ok)

      json_response = JSON.parse(response.body)
      expect(json_response["result"]["content"][0]["text"]).to include("Project created successfully")
      expect(json_response["result"]["content"][0]["text"]).to include("API Test Project")
    end
  end

  describe "update_project_tool" do
    let!(:existing_project) { create(:project, title: "Existing API Project") }

    let(:updated_content) do
      <<~MARKDOWN
        ---
        title: Existing API Project
        category: project
        icon: fa-solid fa-star
        color: gold
        technologies: Python, Django, Redis
        position: 50
        published_date: 2025-08-20
        ---

        Updated project description via API.
      MARKDOWN
    end

    let(:request_body) do
      {
        jsonrpc: "2.0",
        id: "test-2",
        method: "tools/call",
        params: {
          name: "update_project_tool",
          arguments: {
            title: "Existing API Project",
            content: updated_content
          }
        }
      }.to_json
    end

    it "updates an existing project" do
      post api_mcp_path, params: request_body, headers: headers

      expect(response).to have_http_status(:ok)

      json_response = JSON.parse(response.body)
      expect(json_response["result"]["content"][0]["text"]).to include("Project updated successfully")
      expect(json_response["result"]["content"][0]["text"]).to include("Existing API Project")

      updated_project = Project.find_by(title: "Existing API Project")
      expect(updated_project.icon).to eq("fa-solid fa-star")
      expect(updated_project.color).to eq("gold")
    end
  end

  describe "find_project_tool" do
    let!(:project) { create(:project, title: "Findable Project") }

    let(:request_body) do
      {
        jsonrpc: "2.0",
        id: "test-3",
        method: "tools/call",
        params: {
          name: "find_project_tool",
          arguments: {
            title: "Findable Project"
          }
        }
      }.to_json
    end

    it "finds an existing project" do
      post api_mcp_path, params: request_body, headers: headers

      expect(response).to have_http_status(:ok)

      json_response = JSON.parse(response.body)
      expect(json_response["result"]["content"][0]["text"]).to include("Project found:")
      expect(json_response["result"]["content"][0]["text"]).to include("Findable Project")
      expect(json_response["result"]["content"][0]["text"]).to include("Icon:")
    end
  end

  describe "list_projects_tool" do
    let!(:project1) { create(:project, title: "Project 1", position: 10, published_at: 2.days.ago) }
    let!(:project2) { create(:project, :unpublished, title: "Unpublished Project", position: 20) }

    let(:request_body) do
      {
        jsonrpc: "2.0",
        id: "test-4",
        method: "tools/call",
        params: {
          name: "list_projects_tool",
          arguments: {
            status: "published"
          }
        }
      }.to_json
    end

    it "lists projects based on criteria" do
      post api_mcp_path, params: request_body, headers: headers

      expect(response).to have_http_status(:ok)

      json_response = JSON.parse(response.body)
      expect(json_response["result"]["content"][0]["text"]).to include("Found")
      expect(json_response["result"]["content"][0]["text"]).to include("Project 1")
      expect(json_response["result"]["content"][0]["text"]).not_to include("Unpublished Project")
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

    it "includes project tools in the available tools list" do
      post api_mcp_path, params: request_body, headers: headers

      expect(response).to have_http_status(:ok)

      json_response = JSON.parse(response.body)
      tool_names = json_response["result"]["tools"].map { |tool| tool["name"] }

      expect(tool_names).to include("create_project_tool")
      expect(tool_names).to include("update_project_tool")
      expect(tool_names).to include("find_project_tool")
      expect(tool_names).to include("list_projects_tool")
    end
  end
end
