FactoryBot.define do
  factory :release_platform do
    train { association :train }
    app { train.app }
    name { "train" }
    status { "draft" }
    platform { "android" }

    trait :draft do
      status { "draft" }
    end

    trait :active do
      status { "active" }
    end

    trait :inactive do
      status { "inactive" }
    end
  end
end
