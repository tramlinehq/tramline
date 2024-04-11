FactoryBot.define do
  factory :release_index do
    association :train
    tolerable_range { 0.1..0.2 }
  end
end
