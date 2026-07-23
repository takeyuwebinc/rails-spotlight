# frozen_string_literal: true

FactoryBot.define do
  factory :adr_management_search_miss_report, class: "AdrManagement::SearchMissReport" do
    query { "リリース作業の手順はどう決めた？" }
    adr { nil }
    note { "キーワード検索（デプロイ）で到達した" }
    origin { "test" }
  end
end
