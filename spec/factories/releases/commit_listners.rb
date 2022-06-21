FactoryBot.define do
  factory :releases_commit_listner, class: 'Releases::CommitListner' do
    association :train, factory: :releases_train
    branch_name { 'feat/new_story' }
  end
end
