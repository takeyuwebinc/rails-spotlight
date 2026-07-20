# frozen_string_literal: true

FactoryBot.define do
  factory :client do
    sequence(:code) { |n| "shared-client-#{n}" }
    sequence(:name) { |n| "共有クライアント#{n}" }
  end
end
