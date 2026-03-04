FactoryBot.define do
  factory :forward_merge_queue do
    release { association :release }
    status { "pending" }
  end
end
