FactoryBot.define do
  factory :tag do
    sequence(:name) { |n| "Tag#{n}" }
    # Colors will be set automatically by the model's random color generation

    trait :rails do
      name { "Rails" }
      bg_color { "red-600" }
      text_color { "red-100" }
    end

    trait :javascript do
      name { "JavaScript" }
      bg_color { "yellow-500" }
      text_color { "yellow-900" }
    end

    trait :docker do
      name { "Docker" }
      bg_color { "purple-600" }
      text_color { "purple-100" }
    end

    trait :kamal do
      name { "Kamal" }
      bg_color { "blue-600" }
      text_color { "blue-100" }
    end

    trait :devops do
      name { "DevOps" }
      bg_color { "green-600" }
      text_color { "green-100" }
    end
  end
end
