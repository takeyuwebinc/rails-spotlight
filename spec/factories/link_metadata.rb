FactoryBot.define do
  factory :link_metadatum do
    sequence(:url) { |n| "https://example.com/page-#{n}" }
    title { "Example Page Title" }
    description { "This is an example page description for testing purposes." }
    domain { "example.com" }
    favicon { "https://example.com/favicon.ico" }
    image_url { "https://example.com/image.jpg" }
    last_fetched_at { Time.current }

    trait :expired do
      last_fetched_at { 25.hours.ago }
    end

    trait :valid do
      last_fetched_at { 1.hour.ago }
    end
  end
end
