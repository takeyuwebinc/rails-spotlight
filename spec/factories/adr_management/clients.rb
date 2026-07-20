# frozen_string_literal: true

FactoryBot.define do
  factory :adr_management_client, class: "AdrManagement::Client" do
    sequence(:code) { |n| "adr-client-#{n}" }
    sequence(:name) { |n| "ADRクライアント#{n}" }
  end
end
