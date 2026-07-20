# frozen_string_literal: true

require "rails_helper"

RSpec.describe "AdrManagement Reevaluation Check Tools" do
  let(:server_context) { { origin: "oauth:Test Agent" } }
  let(:engagement) { create(:adr_management_engagement, code: "demo") }
  let(:adr) do
    create(:adr_management_adr, engagement: engagement, status: "accepted",
      reevaluation_conditions: "無償枠が改定された場合")
  end

  def response_text(response)
    response.content.first[:text]
  end

  describe Tools::RecordReevaluationCheckTool do
    it "records a no_trigger check with default date and reports it" do
      text = response_text(described_class.call(
        engagement_code: adr.engagement.code, number: adr.number,
        result: "no_trigger", server_context: server_context
      ))

      expect(text).to include("Reevaluation check recorded", adr.display_number, "no_trigger")
      check = adr.reevaluation_checks.sole
      expect(check.checked_on).to eq(Date.current)
      expect(check.origin).to eq("oauth:Test Agent")
    end

    it "records a suspected check and guides toward supersession" do
      text = response_text(described_class.call(
        engagement_code: adr.engagement.code, number: adr.number,
        result: "suspected", note: "無償枠廃止のアナウンスを確認",
        server_context: server_context
      ))

      expect(text).to include("suspected", "無償枠廃止のアナウンスを確認", "superseded_numbers")
    end

    it "returns a typed error for suspected without note" do
      text = response_text(described_class.call(
        engagement_code: adr.engagement.code, number: adr.number,
        result: "suspected", server_context: server_context
      ))

      expect(text).to include("種別: invalid_input", "note")
      expect(adr.reevaluation_checks).to be_empty
    end

    it "returns a typed error for unknown ADR numbers" do
      text = response_text(described_class.call(
        engagement_code: engagement.code, number: 999,
        result: "no_trigger", server_context: server_context
      ))

      expect(text).to include("種別: master_not_found")
    end

    it "returns a typed error for malformed dates" do
      text = response_text(described_class.call(
        engagement_code: adr.engagement.code, number: adr.number,
        result: "no_trigger", checked_on: "not-a-date", server_context: server_context
      ))

      expect(text).to include("種別: invalid_input", "checked_on")
    end

    it "returns a typed error for non-accepted ADRs" do
      proposed = create(:adr_management_adr, engagement: engagement, status: "proposed",
        reevaluation_conditions: "条件あり")
      text = response_text(described_class.call(
        engagement_code: engagement.code, number: proposed.number,
        result: "no_trigger", server_context: server_context
      ))

      expect(text).to include("種別: check_not_allowed")
    end
  end
end
