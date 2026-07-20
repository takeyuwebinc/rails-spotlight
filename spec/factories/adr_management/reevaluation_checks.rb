# frozen_string_literal: true

FactoryBot.define do
  factory :adr_management_reevaluation_check, class: "AdrManagement::ReevaluationCheck" do
    association :adr, factory: :adr_management_adr
    checked_on { Date.new(2026, 7, 10) }
    result { "no_trigger" }
    note { nil }
    origin { "test" }
  end
end
