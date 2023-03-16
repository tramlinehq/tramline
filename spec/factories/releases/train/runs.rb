FactoryBot.define do
  factory :releases_train_run, class: "Releases::Train::Run" do
    association :train, factory: :releases_train
    code_name { Faker::FunnyName.name }
    scheduled_at { Time.current }
    status { "on_track" }
    branch_name { "branch" }
    release_version { "1.2.3" }

    trait :created do
      status { "created" }
    end

    trait :on_track do
      status { "on_track" }
    end

    trait :post_release_started do
      status { "post_release_started" }
    end
  end
end
