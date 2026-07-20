# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::ReevaluationCheck do
  describe "validations" do
    it "is valid with no_trigger and no note" do
      check = build(:adr_management_reevaluation_check, result: "no_trigger", note: nil)
      expect(check).to be_valid
    end

    it "rejects unknown results" do
      check = build(:adr_management_reevaluation_check, result: "unknown")
      expect(check).not_to be_valid
      expect(check.errors[:result]).to be_present
    end

    it "requires a note when suspected" do
      check = build(:adr_management_reevaluation_check, result: "suspected", note: nil)
      expect(check).not_to be_valid
      expect(check.errors[:note]).to be_present
    end

    it "is valid when suspected with a note" do
      check = build(:adr_management_reevaluation_check, result: "suspected", note: "無償枠の改定を観測")
      expect(check).to be_valid
    end
  end

  describe ".adr_ids_checked_within" do
    it "includes ADRs checked more recently than the cutoff and excludes checks exactly at the cutoff" do
      fresh = create(:adr_management_reevaluation_check, checked_on: Date.current - 29)
      boundary = create(:adr_management_reevaluation_check, checked_on: Date.current - 30)
      old = create(:adr_management_reevaluation_check, checked_on: Date.current - 31)

      ids = described_class.adr_ids_checked_within(30)
      expect(ids).to include(fresh.adr_id)
      expect(ids).not_to include(boundary.adr_id, old.adr_id)
    end
  end

  describe ".adr_ids_with_latest_result" do
    it "matches on the latest check, resolving same-day ties by id" do
      adr = create(:adr_management_adr)
      create(:adr_management_reevaluation_check, adr: adr, checked_on: Date.new(2026, 7, 1),
        result: "suspected", note: "観測メモ")
      create(:adr_management_reevaluation_check, adr: adr, checked_on: Date.new(2026, 7, 2),
        result: "no_trigger")

      expect(described_class.adr_ids_with_latest_result("no_trigger")).to include(adr.id)
      expect(described_class.adr_ids_with_latest_result("suspected")).not_to include(adr.id)

      create(:adr_management_reevaluation_check, adr: adr, checked_on: Date.new(2026, 7, 2),
        result: "suspected", note: "同日の後発観測")
      expect(described_class.adr_ids_with_latest_result("suspected")).to include(adr.id)
    end
  end

  it "is deleted together with its ADR" do
    check = create(:adr_management_reevaluation_check)
    expect { check.adr.destroy! }.to change(described_class, :count).by(-1)
  end
end
