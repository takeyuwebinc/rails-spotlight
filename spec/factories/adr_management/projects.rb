# frozen_string_literal: true

FactoryBot.define do
  factory :adr_management_project, class: "AdrManagement::Project" do
    association :engagement, factory: :adr_management_engagement
    sequence(:name) { |n| "保守開発#{n}年度" }
    start_date { Date.new(2026, 4, 1) }
    end_date { Date.new(2027, 3, 31) }
  end
end
