# frozen_string_literal: true

FactoryBot.define do
  factory :adr_management_engagement, class: "AdrManagement::Engagement" do
    association :client, factory: :adr_management_client
    sequence(:code) { |n| "engagement-#{n}" }
    sequence(:name) { |n| "案件#{n}" }
    description { nil }
  end
end
