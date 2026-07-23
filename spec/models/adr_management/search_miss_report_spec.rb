# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::SearchMissReport do
  describe "validations" do
    it "is valid with a factory, with and without a reached ADR" do
      expect(build(:adr_management_search_miss_report)).to be_valid
      expect(build(:adr_management_search_miss_report, adr: create(:adr_management_adr))).to be_valid
    end

    it "requires query, note and origin" do
      expect(build(:adr_management_search_miss_report, query: nil)).not_to be_valid
      expect(build(:adr_management_search_miss_report, note: nil)).not_to be_valid
      expect(build(:adr_management_search_miss_report, origin: nil)).not_to be_valid
    end
  end
end
