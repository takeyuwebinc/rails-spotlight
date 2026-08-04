# frozen_string_literal: true

FactoryBot.define do
  factory :adr_management_search_evaluation, class: "AdrManagement::SearchEvaluation" do
    k { 10 }
    recall { 1.0 }
    details { [] }
    origin { "manual" }
  end
end
