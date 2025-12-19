FactoryBot.define do
  factory :submission_external_config, class: "Config::SubmissionExternal" do
    association :submission_config
    sequence(:identifier) { |n| "channel_#{n}" }
    sequence(:name) { |n| "Channel #{n}" }
    internal { true }
  end
end
