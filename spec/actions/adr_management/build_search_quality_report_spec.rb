# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::BuildSearchQualityReport do
  it "builds a report with per-mode counts, zero-result rate and miss report details" do
    create(:adr_management_search_log, mode: "natural_language", result_count: 3)
    create(:adr_management_search_log, mode: "natural_language", result_count: 0)
    create(:adr_management_search_log, mode: "keyword", result_count: 5)
    adr = create(:adr_management_adr)
    create(:adr_management_search_miss_report, adr: adr, query: "リリース作業の手順は？")

    result = described_class.perform(since: 30.days.ago)

    expect(result).to be_success
    text = result.data[:text]
    expect(text).to include("検索実行数: 3 件")
    expect(text).to include("natural_language: 2 件", "keyword: 1 件")
    expect(text).to include("0件検索: 1 件（33.3%）")
    expect(text).to include("取り逃がし報告: 1 件")
    expect(text).to include(adr.display_number, "リリース作業の手順は？")
    expect(text).to include("判断の目安", "SPOTLIGHT-RAILS-38", "record_reevaluation_check_tool")
    expect(result.data[:miss_report_count]).to eq(1)
  end

  it "builds a report without a rate when there are no searches" do
    result = described_class.perform(since: 30.days.ago)

    text = result.data[:text]
    expect(text).to include("検索実行数: 0 件")
    expect(text).to include("0件検索: 0 件")
    expect(text).not_to include("%")
  end
end
