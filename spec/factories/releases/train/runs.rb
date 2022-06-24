FactoryBot.define do
  factory :releases_train_run, class: 'Releases::Train::Run' do
    association :train, factory: 'releases_train'
    code_name { 'abcd' }
    scheduled_at { Time.current }
    status { 'on_track' }
    branch_name { 'branch' }
  end
end
