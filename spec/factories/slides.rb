FactoryBot.define do
  factory :slide do
    sequence(:title) { |n| "Slide Title #{n}" }
    sequence(:slug) { |n| "slide-slug-#{n}" }
    description { "This is a description for the slide presentation" }
    published_at { Time.current }

    trait :with_pages do
      after(:create) do |slide|
        (1..3).each do |position|
          create(:slide_page, slide: slide, position: position)
        end
      end
    end

    trait :draft do
      published_at { 1.day.from_now }
    end

    trait :with_tags do
      after(:create) do |slide|
        create_list(:tag, 2).each do |tag|
          slide.tags << tag
        end
      end
    end
  end
end
