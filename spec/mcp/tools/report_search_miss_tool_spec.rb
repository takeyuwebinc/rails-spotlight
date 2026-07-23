# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::ReportSearchMissTool do
  let(:server_context) { { origin: "oauth:Test Agent" } }

  def response_text(response)
    response.content.first[:text]
  end

  it "records a miss report with the reached ADR" do
    engagement = create(:adr_management_engagement, code: "fabble")
    adr = create(:adr_management_adr, engagement: engagement)

    text = response_text(described_class.call(
      query: "リリース作業の手順は？", note: "keyword: デプロイ で到達",
      engagement_code: "fabble", number: adr.number, server_context: server_context
    ))

    expect(text).to include("Search miss reported", "FABBLE-#{adr.number}")
    report = AdrManagement::SearchMissReport.last
    expect(report.adr).to eq(adr)
    expect(report.origin).to eq("oauth:Test Agent")
  end

  it "records a miss report without a reached ADR" do
    text = response_text(described_class.call(
      query: "決めた記憶があるが見つからない", note: "複数の言い回しでも0件",
      server_context: server_context
    ))

    expect(text).to include("Search miss reported", "(none)")
    expect(AdrManagement::SearchMissReport.last.adr).to be_nil
  end

  it "rejects specifying only one of engagement_code and number" do
    text = response_text(described_class.call(
      query: "q", note: "n", engagement_code: "fabble", server_context: server_context
    ))

    expect(text).to include("種別: invalid_input", "両方")
    expect(AdrManagement::SearchMissReport.count).to eq(0)
  end

  it "returns master_not_found for an unknown engagement or number" do
    engagement = create(:adr_management_engagement, code: "fabble")

    unknown_engagement = response_text(described_class.call(
      query: "q", note: "n", engagement_code: "nope", number: 1, server_context: server_context
    ))
    expect(unknown_engagement).to include("種別: master_not_found")

    unknown_number = response_text(described_class.call(
      query: "q", note: "n", engagement_code: engagement.code, number: 999, server_context: server_context
    ))
    expect(unknown_number).to include("種別: master_not_found", "search_adrs_tool")
  end
end
