# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::ReportSearchMiss do
  it "records a miss report with a reached ADR" do
    adr = create(:adr_management_adr)

    result = described_class.perform(
      query: "リリース作業の手順は？", note: "keyword: デプロイ で到達",
      adr: adr, origin: "oauth:Agent"
    )

    expect(result).to be_success
    report = result.data
    expect(report.query).to eq("リリース作業の手順は？")
    expect(report.adr).to eq(adr)
    expect(report.origin).to eq("oauth:Agent")
  end

  it "records a miss report without a reached ADR" do
    result = described_class.perform(
      query: "決めた記憶があるが見つからない", note: "複数の言い回しでも0件", origin: "test"
    )

    expect(result).to be_success
    expect(result.data.adr).to be_nil
  end

  it "returns invalid_input errors when required attributes are blank" do
    result = described_class.perform(query: "", note: "", origin: "test")

    expect(result).to be_failure
    expect(result.errors.map(&:kind)).to all(eq(:invalid_input))
    expect(result.errors.map(&:param)).to include("query", "note")
  end
end
