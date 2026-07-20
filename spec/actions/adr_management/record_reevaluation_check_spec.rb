# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::RecordReevaluationCheck do
  let(:adr) do
    create(:adr_management_adr, status: "accepted",
      reevaluation_conditions: "無償枠が改定された場合")
  end

  def perform(adr:, attributes:)
    described_class.perform(adr: adr, attributes: attributes, origin: "oauth:Test Agent")
  end

  it "records a check with the given date and origin" do
    result = perform(adr: adr, attributes: { result: "no_trigger", checked_on: Date.current - 1 })

    expect(result).to be_success
    check = result.data
    expect(check.checked_on).to eq(Date.current - 1)
    expect(check.result).to eq("no_trigger")
    expect(check.origin).to eq("oauth:Test Agent")
  end

  it "defaults checked_on to today" do
    result = perform(adr: adr, attributes: { result: "no_trigger" })
    expect(result.data.checked_on).to eq(Date.current)
  end

  it "does not create a revision" do
    expect {
      perform(adr: adr, attributes: { result: "no_trigger" })
    }.not_to change(AdrManagement::AdrRevision, :count)
  end

  it "rejects future check dates" do
    result = perform(adr: adr, attributes: { result: "no_trigger", checked_on: Date.current + 1 })

    expect(result).to be_failure
    expect(result.errors.first.kind).to eq(:invalid_input)
    expect(result.errors.first.param).to eq("checked_on")
  end

  it "rejects non-accepted ADRs" do
    proposed = create(:adr_management_adr, status: "proposed",
      reevaluation_conditions: "条件あり")
    result = perform(adr: proposed, attributes: { result: "no_trigger" })

    expect(result).to be_failure
    expect(result.errors.first.kind).to eq(:check_not_allowed)
  end

  it "rejects ADRs without reevaluation conditions" do
    plain = create(:adr_management_adr, status: "accepted", reevaluation_conditions: nil)
    result = perform(adr: plain, attributes: { result: "no_trigger" })

    expect(result).to be_failure
    expect(result.errors.first.kind).to eq(:check_not_allowed)
  end

  it "rejects suspected without a note as invalid input" do
    result = perform(adr: adr, attributes: { result: "suspected" })

    expect(result).to be_failure
    expect(result.errors.first.kind).to eq(:invalid_input)
    expect(result.errors.first.param).to eq("note")
  end
end
