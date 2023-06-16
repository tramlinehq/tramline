FactoryBot.define do
  factory :release_platform do
    train { association :train }
    app { train.app }
    name { "train" }
    platform { "android" }
  end
end
