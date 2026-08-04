# frozen_string_literal: true

FactoryBot.define do
  factory :adr_management_golden_query, class: "AdrManagement::GoldenQuery" do
    association :adr, factory: :adr_management_adr
    sequence(:query) { |n| "ゴールデンクエリ#{n}" }
    note { nil }
    origin { "test" }
  end
end
