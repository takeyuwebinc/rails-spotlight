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

  describe ".record" do
    it "stores the search with stringified filters" do
      engagement = create(:adr_management_engagement)

      log = described_class.record(
        mode: "natural_language", query: "認証まわりの決定", keyword: "認証",
        engagement: engagement, filters: { status: "accepted", confidence: nil },
        results: [ { adr_id: 1, score: 0.87 } ], result_count: 1, origin: "admin:me@example.com"
      )

      expect(log.mode).to eq("natural_language")
      expect(log.engagement).to eq(engagement)
      expect(log.filters).to eq("status" => "accepted")
      expect(log.results).to eq([ { "adr_id" => 1, "score" => 0.87 } ])
      expect(log.origin).to eq("admin:me@example.com")
    end

    # ログは分析用であり検索の契約に含めない（記録失敗で検索を失敗させない）
    it "does not raise when the record cannot be saved" do
      expect(Rails.error).to receive(:report).with(instance_of(ActiveRecord::RecordInvalid), handled: true)

      expect {
        described_class.record(mode: "unknown", results: [], result_count: 0, origin: "admin:me@example.com")
      }.not_to raise_error
    end
  end

  describe ".pending_review" do
    it "returns zero-result logs that have not been reviewed" do
      pending = create(:adr_management_search_log, result_count: 0)
      create(:adr_management_search_log, result_count: 0, reviewed_at: Time.current)
      create(:adr_management_search_log, result_count: 3)

      expect(described_class.pending_review).to eq([ pending ])
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
