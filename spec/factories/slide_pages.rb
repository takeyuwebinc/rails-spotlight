FactoryBot.define do
  factory :slide_page do
    slide
    sequence(:position, 1) { |n| n }
    content { "<h1>Page #{position}</h1><p>This is the content for page #{position}</p>" }
  end
end
