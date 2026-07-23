# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::SearchLog do
  describe "validations" do
    it "is valid with a factory" do
      expect(build(:adr_management_search_log)).to be_valid
    end

    it "requires a known mode" do
      expect(build(:adr_management_search_log, mode: nil)).not_to be_valid
      expect(build(:adr_management_search_log, mode: "unknown")).not_to be_valid
    end

    it "requires a non-negative integer result_count" do
      expect(build(:adr_management_search_log, result_count: nil)).not_to be_valid
      expect(build(:adr_management_search_log, result_count: -1)).not_to be_valid
    end

    it "requires origin" do
      expect(build(:adr_management_search_log, origin: nil)).not_to be_valid
    end
  end

  describe ".summary" do
    it "aggregates totals, per-mode counts and zero-result counts within the period" do
      create(:adr_management_search_log, mode: "natural_language", result_count: 3)
      create(:adr_management_search_log, mode: "natural_language", result_count: 0)
      create(:adr_management_search_log, mode: "keyword", result_count: 5)
      old = create(:adr_management_search_log, mode: "keyword", result_count: 0)
      old.update_column(:created_at, 60.days.ago)

      summary = described_class.summary(since: 30.days.ago)

      expect(summary[:total]).to eq(3)
      expect(summary[:by_mode]).to eq("natural_language" => 2, "keyword" => 1)
      expect(summary[:zero_result_count]).to eq(1)
    end
  end
end
