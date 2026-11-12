FactoryBot.define do
  factory :incident do
    feed
    sequence(:external_id) { |n| "incident-#{n}" }
    title { "Degraded performance" }
    impact { "minor" }
    status { "resolved" }
    started_at { 3.days.ago }
    resolved_at { started_at + 2.hours }

    trait :ongoing do
      status { "investigating" }
      resolved_at { nil }
    end
  end
end
