# frozen_string_literal: true

require "rails_helper"

RSpec.describe "AdrManagement Write Tools" do
  let(:server_context) { { origin: "oauth:Test Agent" } }
  let!(:engagement) { create(:adr_management_engagement, code: "fabble") }

  def response_text(response)
    response.content.first[:text]
  end

  describe Tools::RegisterAdrTool do
    let(:base_params) do
      {
        engagement_code: "fabble",
        title: "認証方式の選定",
        confidence: "high",
        context: "コンテキスト",
        decision: "決定",
        consequences: "結果",
        server_context: server_context
      }
    end

    it "registers an adr with an auto-issued number and records the origin" do
      text = response_text(described_class.call(**base_params))

      expect(text).to include("registered successfully", "fabble-1")
      adr = engagement.adrs.sole
      expect(adr.status).to eq("accepted")
      expect(adr.revisions.sole.origin).to eq("oauth:Test Agent")
    end

    it "registers with a project and proposed status" do
      create(:adr_management_project, engagement: engagement, name: "2026年度")

      text = response_text(described_class.call(
        **base_params, status: "proposed", project_name: "2026年度", decided_on: "2026-07-01"
      ))

      expect(text).to include("Status: proposed")
      adr = engagement.adrs.sole
      expect(adr.project.name).to eq("2026年度")
      expect(adr.decided_on).to eq(Date.new(2026, 7, 1))
    end

    it "supersedes existing adrs atomically" do
      old_adr = create(:adr_management_adr, engagement: engagement, status: "accepted")

      text = response_text(described_class.call(**base_params, superseded_numbers: [ old_adr.number ]))

      expect(text).to include("Superseded: fabble-#{old_adr.number}")
      expect(old_adr.reload.status).to eq("superseded")
    end

    it "returns a structured error for an invalid supersession target" do
      proposed = create(:adr_management_adr, engagement: engagement, status: "proposed")

      text = response_text(described_class.call(**base_params, superseded_numbers: [ proposed.number ]))

      expect(text).to include("種別: invalid_supersession")
      expect(engagement.adrs.count).to eq(1)
    end

    it "returns master_not_found for an unknown engagement" do
      text = response_text(described_class.call(**base_params, engagement_code: "nope"))
      expect(text).to include("種別: master_not_found", "create_adr_engagement_tool")
    end

    it "returns master_not_found for an unknown project" do
      text = response_text(described_class.call(**base_params, project_name: "nope"))
      expect(text).to include("種別: master_not_found", "原因パラメータ: project_name", "create_adr_project_tool")
    end
  end

  describe Tools::UpdateAdrTool do
    let!(:adr) { create(:adr_management_adr, engagement: engagement, status: "proposed", title: "旧タイトル") }

    it "updates content and status with a revision recording the origin" do
      text = response_text(described_class.call(
        engagement_code: "fabble", number: adr.number,
        title: "新タイトル", status: "accepted", server_context: server_context
      ))

      expect(text).to include("updated successfully", "新タイトル", "Status: accepted")
      revision = adr.revisions.where(change_type: "updated").sole
      expect(revision.origin).to eq("oauth:Test Agent")
      expect(revision.snapshot["title"]).to eq("旧タイトル")
    end

    it "returns a structured error for a forbidden status transition" do
      adr.update!(status: "accepted")

      text = response_text(described_class.call(
        engagement_code: "fabble", number: adr.number,
        status: "rejected", server_context: server_context
      ))

      expect(text).to include("種別: invalid_status_transition", "次のアクション")
      expect(adr.reload.status).to eq("accepted")
    end

    it "returns invalid_input when no updatable fields are given" do
      text = response_text(described_class.call(
        engagement_code: "fabble", number: adr.number, server_context: server_context
      ))
      expect(text).to include("種別: invalid_input", "更新する項目")
    end

    it "returns master_not_found for an unknown adr number" do
      text = response_text(described_class.call(
        engagement_code: "fabble", number: 999, title: "x", server_context: server_context
      ))
      expect(text).to include("種別: master_not_found")
    end
  end
end
