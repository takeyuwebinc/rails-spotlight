FactoryBot.define do
  factory :project do
    sequence(:title) { |n| "Test Project #{n}" }
    description { "This is a test project description." }
    icon { "fa-solid fa-code" }
    color { "blue" }
    technologies { "Ruby, Rails, PostgreSQL" }
    sequence(:position) { |n| n * 10 }
    published_at { 1.day.ago }

    trait :unpublished do
      published_at { 1.day.from_now }
    end
  end
end
