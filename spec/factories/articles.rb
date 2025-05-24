FactoryBot.define do
  factory :article do
    title { "Sample Article Title" }
    slug { "sample-article-title" }
    description { "This is a sample article description for testing purposes." }
    content { "<h1>Sample Content</h1><p>This is sample content for testing.</p>" }
    published_at { 1.day.ago }

    trait :unpublished do
      published_at { 1.day.from_now }
    end

    trait :with_custom_slug do
      sequence(:slug) { |n| "custom-article-#{n}" }
    end
  end
end
