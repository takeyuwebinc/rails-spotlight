# frozen_string_literal: true

FactoryBot.define do
  factory :work_hour_work_entry, class: "WorkHour::WorkEntry" do
    association :project, factory: :work_hour_project
    worked_on { Date.current }
    target_month { Date.current.beginning_of_month }
    description { "作業内容" }
    minutes { 60 }

    trait :without_project do
      project { nil }
    end
  end
end
