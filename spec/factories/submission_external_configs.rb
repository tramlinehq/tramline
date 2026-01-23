FactoryBot.define do
  factory :submission_external_config, class: "Config::SubmissionExternal" do
    submission_config
    sequence(:identifier) { |n| "channel_#{n}" }
    sequence(:name) { |n| "Channel #{n}" }
    internal { true }
  end
end
