# frozen_string_literal: true

FactoryBot.define do
  factory :adr_management_adr, class: "AdrManagement::Adr" do
    association :engagement, factory: :adr_management_engagement
    number { nil }
    sequence(:title) { |n| "決定タイトル#{n}" }
    status { "accepted" }
    confidence { "high" }
    decided_on { Date.new(2026, 7, 1) }
    context { "現状の問題点・制約条件" }
    decision { "採用した実装方針" }
    consequences { "ポジティブ/ネガティブな影響" }
    alternatives { nil }
    reevaluation_conditions { nil }
    reference_links { nil }

    after(:build) do |adr|
      adr.number ||= adr.engagement&.persisted? ? adr.engagement.issue_next_number! : 1
    end
  end
end
