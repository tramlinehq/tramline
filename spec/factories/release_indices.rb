FactoryBot.define do
  factory :release_index do
    association :train
    tolerable_range { 1..10 }
  end
end
