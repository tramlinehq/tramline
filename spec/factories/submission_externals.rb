FactoryBot.define do
  factory :submission_external do
    association :submission
    sequence(:identifier) { |n| "channel_#{n}" }
    sequence(:name) { |n| "Channel #{n}" }
    internal { true }
  end
end 