# frozen_string_literal: true

FactoryBot.define do
  factory :adr_management_quality_assessment, class: "AdrManagement::QualityAssessment" do
    association :adr, factory: :adr_management_adr
    layer { "rule" }
    content_fingerprint { "0" * 64 }
    findings do
      [ { "code" => "alternatives_missing", "field" => "alternatives",
          "message" => "代替案が記録されていません" } ]
    end
    origin { "test" }
  end
end
