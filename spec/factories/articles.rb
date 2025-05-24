FactoryBot.define do
  factory :article do
    sequence(:title) { |n| "Sample Article Title #{n}" }
    sequence(:slug) { |n| "sample-article-title-#{n}" }
    description { "This is a sample article description for testing purposes." }
    content { "<h1>Sample Content</h1><p>This is sample content for testing.</p>" }
    published_at { 1.day.ago }

    trait :unpublished do
      published_at { 1.day.from_now }
    end

    trait :with_custom_slug do
      sequence(:slug) { |n| "custom-article-#{n}" }
    end

    trait :with_tags do
      after(:create) do |article|
        article.tags << create(:tag, :rails)
        article.tags << create(:tag, :javascript)
      end
    end

    trait :with_rails_tag do
      after(:create) do |article|
        rails_tag = Tag.find_by(name: "Rails") || create(:tag, :rails)
        article.tags << rails_tag unless article.tags.include?(rails_tag)
      end
    end

    trait :with_kamal_tag do
      after(:create) do |article|
        kamal_tag = Tag.find_by(name: "Kamal") || create(:tag, :kamal)
        article.tags << kamal_tag unless article.tags.include?(kamal_tag)
      end
    end
  end
end
