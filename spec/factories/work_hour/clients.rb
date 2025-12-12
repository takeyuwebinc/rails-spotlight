# frozen_string_literal: true

FactoryBot.define do
  factory :work_hour_client, class: "WorkHour::Client" do
    sequence(:code) { |n| "client-#{n}" }
    sequence(:name) { |n| "クライアント#{n}" }
  end
end
