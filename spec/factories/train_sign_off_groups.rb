FactoryBot.define do
  factory :train_sign_off_group do
    association :train, factory: 'releases_train'
    sign_off_group
  end
end
