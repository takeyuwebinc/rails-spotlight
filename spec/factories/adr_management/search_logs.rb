# frozen_string_literal: true

FactoryBot.define do
  factory :adr_management_search_log, class: "AdrManagement::SearchLog" do
    mode { "natural_language" }
    query { "認証まわりで過去に決めたことは？" }
    keyword { nil }
    engagement { nil }
    filters { {} }
    results { [] }
    result_count { 0 }
    origin { "test" }
  end
end
