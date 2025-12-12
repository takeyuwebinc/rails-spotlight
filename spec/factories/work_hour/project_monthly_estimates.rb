# frozen_string_literal: true

FactoryBot.define do
  factory :work_hour_project_monthly_estimate, class: "WorkHour::ProjectMonthlyEstimate" do
    association :project, factory: :work_hour_project
    year_month { Date.current.beginning_of_month }
    estimated_hours { 80 }
  end
end
