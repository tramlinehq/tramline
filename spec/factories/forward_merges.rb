FactoryBot.define do
  factory :forward_merge do
    release { association :release }
    status { "pending" }
  end
end
