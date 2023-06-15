FactoryBot.define do
  factory :commit_listener, class: "CommitListener" do
    association :train
    branch_name { "feat/new_story" }
  end
end
