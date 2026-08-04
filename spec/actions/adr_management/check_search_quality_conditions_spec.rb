# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::CheckSearchQualityConditions do
  it "returns no_trigger with measurements when no condition is met" do
    create(:adr_management_search_log, result_count: 3)

    result = described_class.perform

    expect(result.data[:result]).to eq("no_trigger")
    expect(result.data[:note]).to include("自動点検", "検索ログ総数 1 件", "評価未実行")
    expect(result.data[:note]).not_to include("発火疑い")
  end

  it "suspects when miss reports reach the monthly threshold" do
    3.times { create(:adr_management_search_miss_report) }

    result = described_class.perform

    expect(result.data[:result]).to eq("suspected")
    expect(result.data[:note]).to include("発火疑い", "月3件以上", "3 件")
  end

  it "suspects a silent report channel after 3 months of searches without reports" do
    old = create(:adr_management_search_log)
    old.update_column(:created_at, 4.months.ago)
    create(:adr_management_search_log, result_count: 2)

    result = described_class.perform

    expect(result.data[:result]).to eq("suspected")
    expect(result.data[:note]).to include("発火疑い", "報告経路")
  end

  it "does not suspect the report channel before 3 months of observation" do
    create(:adr_management_search_log, result_count: 2)

    expect(described_class.perform.data[:result]).to eq("no_trigger")
  end

  it "suspects when recall drops from the previous evaluation" do
    evaluation = create(:adr_management_search_evaluation, recall: 0.8)
    previous = create(:adr_management_search_evaluation, recall: 1.0)

    result = described_class.perform(evaluation: evaluation, previous_evaluation: previous)

    expect(result.data[:result]).to eq("suspected")
    expect(result.data[:note]).to include("発火疑い", "1.000 → 0.800")
  end

  it "does not suspect when recall is unchanged" do
    evaluation = create(:adr_management_search_evaluation, recall: 1.0)
    previous = create(:adr_management_search_evaluation, recall: 1.0)

    result = described_class.perform(evaluation: evaluation, previous_evaluation: previous)

    expect(result.data[:result]).to eq("no_trigger")
    expect(result.data[:note]).to include("recall@10 1.000", "前回 1.000")
  end
end
