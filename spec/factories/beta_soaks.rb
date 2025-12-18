FactoryBot.define do
  factory :beta_soak do
    release
    started_at { Time.current }
    period_hours { 24 }

    trait :completed_naturally do
      started_at { 25.hours.ago }
    end

    trait :ended do
      ended_at { 1.hour.ago }
    end

    trait :active do
      started_at { 1.hour.ago }
    end

    trait :with_custom_period do
      period_hours { 48 }
    end
  end
end
