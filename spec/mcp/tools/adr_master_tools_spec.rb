# frozen_string_literal: true

require "rails_helper"

RSpec.describe "AdrManagement Master Tools" do
  let(:server_context) { { origin: "oauth:Test Agent" } }

  def response_text(response)
    response.content.first[:text]
  end

  describe Tools::ListAdrClientsTool do
    it "lists clients with engagement counts" do
      client = create(:adr_management_client, code: "acme", name: "ACME商事")
      create(:adr_management_engagement, client: client)

      text = response_text(described_class.call(server_context: server_context))
      expect(text).to include("acme", "ACME商事", "engagements: 1")
    end

    it "guides creation when empty" do
      text = response_text(described_class.call(server_context: server_context))
      expect(text).to include("create_adr_client_tool")
    end
  end

  describe Tools::FindAdrClientTool do
    let!(:client) { create(:adr_management_client, code: "acme", name: "ACME商事") }

    it "finds by exact code" do
      text = response_text(described_class.call(query: "acme", server_context: server_context))
      expect(text).to include("Found client", "acme", "ACME商事")
    end

    it "finds by name partial match" do
      text = response_text(described_class.call(query: "ACME", server_context: server_context))
      expect(text).to include("Found client")
    end

    it "guides when not found" do
      text = response_text(described_class.call(query: "nope", server_context: server_context))
      expect(text).to include("not found", "create_adr_client_tool")
    end
  end

  describe Tools::CreateAdrClientTool do
    it "creates a client together with a shared client" do
      response = described_class.call(code: "acme", name: "ACME商事", server_context: server_context)

      expect(response_text(response)).to include("created successfully")
      expect(AdrManagement::Client.find_by_code("acme")).to be_present
      expect(Client.find_by(code: "acme")).to be_present
    end

    it "reuses an existing shared client registered by another domain" do
      create(:work_hour_client, code: "acme", name: "ACME商事")

      response = described_class.call(code: "acme", name: "ACME商事", server_context: server_context)

      expect(response_text(response)).to include("同一実体")
      expect(Client.where(code: "acme").count).to eq(1)
    end

    it "returns a structured error for duplicates" do
      create(:adr_management_client, code: "acme")

      text = response_text(described_class.call(code: "acme", name: "A", server_context: server_context))
      expect(text).to include("Error", "種別: invalid_input", "原因パラメータ: code", "次のアクション")
    end
  end

  describe Tools::ListAdrEngagementsTool do
    it "lists engagements with adr counts" do
      engagement = create(:adr_management_engagement, code: "fabble", name: "Fabble")
      create(:adr_management_adr, engagement: engagement)

      text = response_text(described_class.call(server_context: server_context))
      expect(text).to include("fabble", "Fabble", "ADRs: 1")
    end

    it "filters by client code" do
      client = create(:adr_management_client, code: "acme")
      create(:adr_management_engagement, client: client, code: "fabble")
      create(:adr_management_engagement, code: "other")

      text = response_text(described_class.call(client_code: "acme", server_context: server_context))
      expect(text).to include("fabble")
      expect(text).not_to include("other")
    end

    it "returns a structured error when the client does not exist" do
      text = response_text(described_class.call(client_code: "nope", server_context: server_context))
      expect(text).to include("種別: master_not_found", "原因パラメータ: client_code", "create_adr_client_tool")
    end
  end

  describe Tools::CreateAdrEngagementTool do
    it "creates an engagement under the client" do
      create(:adr_management_client, code: "acme")

      response = described_class.call(
        code: "fabble", name: "Fabble", client_code: "acme", server_context: server_context
      )

      expect(response_text(response)).to include("created successfully", "fabble")
      expect(AdrManagement::Engagement.find_by(code: "fabble")).to be_present
    end

    it "returns master_not_found when the client is missing" do
      text = response_text(described_class.call(
        code: "fabble", name: "Fabble", client_code: "nope", server_context: server_context
      ))
      expect(text).to include("種別: master_not_found", "create_adr_client_tool")
    end

    it "returns invalid_input for duplicate code" do
      create(:adr_management_client, code: "acme")
      create(:adr_management_engagement, code: "fabble")

      text = response_text(described_class.call(
        code: "fabble", name: "F", client_code: "acme", server_context: server_context
      ))
      expect(text).to include("種別: invalid_input", "原因パラメータ: code")
    end
  end

  describe Tools::ListAdrProjectsTool do
    it "lists projects of the engagement" do
      engagement = create(:adr_management_engagement, code: "fabble")
      create(:adr_management_project, engagement: engagement, name: "保守開発2026")

      text = response_text(described_class.call(engagement_code: "fabble", server_context: server_context))
      expect(text).to include("保守開発2026")
    end

    it "returns master_not_found for a missing engagement" do
      text = response_text(described_class.call(engagement_code: "nope", server_context: server_context))
      expect(text).to include("種別: master_not_found", "create_adr_engagement_tool")
    end
  end

  describe Tools::FindAdrProjectTool do
    it "finds a project by partial name" do
      engagement = create(:adr_management_engagement, code: "fabble")
      create(:adr_management_project, engagement: engagement, name: "保守開発2026年度")

      text = response_text(described_class.call(
        engagement_code: "fabble", query: "2026", server_context: server_context
      ))
      expect(text).to include("Found project", "保守開発2026年度")
    end
  end

  describe Tools::CreateAdrProjectTool do
    let!(:engagement) { create(:adr_management_engagement, code: "fabble") }

    it "creates a project with a period" do
      response = described_class.call(
        engagement_code: "fabble", name: "保守開発2026年度",
        start_date: "2026-04-01", end_date: "2027-03-31", server_context: server_context
      )

      expect(response_text(response)).to include("created successfully")
      project = engagement.projects.sole
      expect(project.start_date).to eq(Date.new(2026, 4, 1))
    end

    it "returns invalid_input for a malformed date" do
      text = response_text(described_class.call(
        engagement_code: "fabble", name: "P", start_date: "not-a-date", server_context: server_context
      ))
      expect(text).to include("種別: invalid_input", "原因パラメータ: start_date", "YYYY-MM-DD")
    end
  end
end
