FactoryBot.define do
  factory :feed do
    sequence(:url) { |n| "https://status#{n}.example.com/api/v2/incidents.json" }
    provider { "statuspage" }
    sequence(:name) { |n| "Example Service #{n}" }

    trait :rss do
      provider { "rss" }
      sequence(:url) { |n| "https://status#{n}.example.org/history.rss" }
    end
  end
end
