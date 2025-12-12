# frozen_string_literal: true

FactoryBot.define do
  factory :work_hour_project, class: "WorkHour::Project" do
    sequence(:code) { |n| "project-#{n}" }
    sequence(:name) { |n| "プロジェクト#{n}" }
    color { "#fa6414" }
    status { "active" }
    start_date { Date.current.beginning_of_month }
    end_date { 1.year.from_now.end_of_month }

    association :client, factory: :work_hour_client

    trait :closed do
      status { "closed" }
    end

    trait :without_client do
      client { nil }
    end
  end
end
