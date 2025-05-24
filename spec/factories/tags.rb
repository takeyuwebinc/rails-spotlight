FactoryBot.define do
  factory :tag do
    sequence(:name) { |n| "Tag#{n}" }
    color { "blue" }

    trait :rails do
      name { "Rails" }
      color { "red" }
    end

    trait :javascript do
      name { "JavaScript" }
      color { "yellow" }
    end

    trait :docker do
      name { "Docker" }
      color { "purple" }
    end

    trait :kamal do
      name { "Kamal" }
      color { "blue" }
    end

    trait :devops do
      name { "DevOps" }
      color { "green" }
    end
  end
end
